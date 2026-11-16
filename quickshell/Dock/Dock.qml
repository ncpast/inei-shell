pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"
import "../Utils"
import "../Widgets"

/* 

Application Dock

    * Sizes itself to its icons: pinned apps (Theme.dock_pinned), then other running apps, then, after
    a divider, minimized windows (hypr/modules/minimize.lua parks them on "special:minimized").

    * Running apps get a glowing Theme.accent border instead of a dot. Minimized windows show their
    app's icon.

    * Auto-hides while the workspace has a tiled, maximized or fullscreen window; with only floating
    windows (or none) it stays. Touching the bottom edge of the screen brings it back.

    * Same layer as the bars and the frame (Top). Slides like the OSDs, on Theme's springs.

    * Icons grow towards the cursor: the icon under it gets Theme.dock_magnification
    times its size, the neighbours less and less (Theme.dock_magnify_range).

Left click: focus the app (again: next window of it); if only minimized windows are left, restore one;
launch it if it isn't running. On a minimized window's own preview: restore that window on the current
workspace. Right click: launch a new window of the app.
Middle click: close all of the app's running instances.

On / off: menu bar > View > Dock (Theme.dock_enabled). Off slides the dock away, then unloads it.

*/

Variants {
    model: Quickshell.screens

    Scope {
        id: unit
        required property var modelData

        // Loaded while the dock is on (Theme.dock_enabled). Turning it off first slides the dock away
        // and unloads it once it has: the window reports that (slidOut) and its Connections below
        // handles the cases where it was already hidden.
        property bool active: Theme.dock_enabled

        Connections {
            target: Theme
            function onDock_enabledChanged() {
                if (Theme.dock_enabled) unit.active = true
                else if (!loader.item || loader.item.slidOut) unit.active = false
            }
        }

        LazyLoader {
            id: loader
            active: unit.active

            PanelWindow {
                id: win
                readonly property var modelData: unit.modelData
                screen: modelData

                // Geometry //

                readonly property real base: Theme.dock_icon_size
                readonly property real mag: Math.max(1, Theme.dock_magnification)
                readonly property real maxIcon: base * mag
                readonly property real overflow: maxIcon - base      // how far a magnified icon reaches above the dock
                readonly property real pad: Theme.dock_padding
                readonly property real gap: Theme.dock_spacing
                readonly property real dividerW: 2
                readonly property real barH: base + 2 * pad
                // room for the drop shadow (Theme.shadow_*), as in the OSD
                readonly property real shadowPad: Theme.shadow_blur * Theme.shadow_blur_max + Math.abs(Theme.shadow_offset)
                readonly property real tipH: 26
                readonly property real tipGap: 8
                readonly property real springRoom: 30                // slide-in overshoot

                // Full width (so the dock can grow and shrink with its icons without the surface being
                // resized), only as tall as the dock reaches; input is limited by "mask".
                anchors { bottom: true; left: true; right: true }
                implicitHeight: Math.ceil(Theme.dock_margin_bottom + barH + overflow + tipGap + tipH + shadowPad + springRoom)
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-dock"
                color: "transparent"

                // Hiding //
                readonly property var workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
                readonly property bool wantHidden: Theme.dock_autohide && workspace !== null
                                                   && HyprEvents.workspaceBlocking[workspace.id] === true
                // The cursor is on the dock or on the trigger strip at the screen's bottom edge.
                property bool hovering: false
                readonly property bool wantShown: Theme.dock_enabled && (!wantHidden || hovering)
                // What's actually showing. Showing is immediate; hiding waits Theme.dock_hide_delay (the cursor
                // leaving, a tiled window opening, a switch to a busy workspace...), and is dropped if the
                // dock is wanted again in the meantime.
                property bool shown: true
                onWantShownChanged: {
                    if (wantShown) {
                        hideTimer.stop()
                        shown = true
                    } else if (!Theme.dock_enabled) {
                        hideTimer.stop()
                        shown = false                        // switched off: away at once, no waiting
                    } else {
                        hideTimer.restart()
                    }
                }

                // hidden and done sliding: with the dock switched off, this is when it's unloaded
                readonly property bool slidOut: !shown && !slideAnim.running
                                                && Math.abs(bar.anchors.bottomMargin - bar.hiddenMargin) < 2
                onSlidOutChanged: if (slidOut && !Theme.dock_enabled) Qt.callLater(() => {
                    if (win.slidOut && !Theme.dock_enabled) unit.active = false
                })
                onShownChanged: scene.applyState()

                Timer {
                    id: hideTimer
                    interval: Theme.dock_hide_delay
                    onTriggered: win.shown = win.wantShown
                }

                // Model //

                // Entries: { key, kind: "app" | "divider" | "minimized", name, icon, command, addrs, address }.
                // Rebuilt on every window event, but applied to the ListModel as a diff, so the delegates (and
                // their loaded icons and shaders) survive.

                function norm(s) { return AppIcons._norm(s) }

                function pinFor(cls, app) {
                    const pins = Theme.dock_pinned
                    const c = norm(cls), a = norm(app)
                    for (let i = 0; i < pins.length; i++) {
                        const keys = [pins[i].icon].concat(pins[i].match || [])
                        for (let k = 0; k < keys.length; k++) {
                            const key = norm(keys[k])
                            if (key === "") continue
                            if (c === key || a === key || (key.length >= 4 && (c.indexOf(key) !== -1 || a.indexOf(key) !== -1)))
                                return i
                        }
                    }
                    return -1
                }

                readonly property var entries: {
                    const pins = Theme.dock_pinned
                    const list = []
                    const byKey = {}
                    for (let i = 0; i < pins.length; i++) {
                        const e = { key: "pin:" + pins[i].name, kind: "app", name: pins[i].name, icon: pins[i].icon,
                                    command: pins[i].command, addrs: [], all: [], address: "" }
                        list.push(e)
                        byKey[e.key] = e
                    }
                    const minimized = []
                    const minimizedOf = []     // which app entry each minimized window belongs to, for "close all"
                    const clients = HyprEvents.clients
                    for (let i = 0; i < clients.length; i++) {
                        const c = clients[i]
                        const p = pinFor(c.cls, c.app)
                        if (c.minimized) {
                            minimized.push({ key: "min:" + c.address, kind: "minimized",
                                             name: c.title !== "" ? c.title : c.app, icon: p >= 0 ? pins[p].icon : c.app,
                                             command: [], addrs: [], all: [], address: c.address,
                                             aspect: c.h > 0 ? c.w / c.h : 1 })
                            minimizedOf.push({ key: p >= 0 ? "pin:" + pins[p].name : "app:" + c.app, address: c.address })
                            continue
                        }
                        const key = p >= 0 ? "pin:" + pins[p].name : "app:" + c.app
                        let e = byKey[key]
                        if (!e) {
                            e = { key: key, kind: "app", name: AppIcons.displayName(c.app, c.app), icon: c.app,
                                  command: [], addrs: [], all: [], address: "" }
                            list.push(e)
                            byKey[key] = e
                        }
                        e.addrs.push(c.address)
                        e.all.push(c.address)
                    }
                    for (let i = 0; i < minimizedOf.length; i++) {
                        const owner = byKey[minimizedOf[i].key]
                        if (owner) owner.all.push(minimizedOf[i].address)
                    }
                    if (minimized.length > 0)
                        list.push({ key: "divider", kind: "divider", name: "", icon: "", command: [], addrs: [], all: [], address: "" })
                    return list.concat(minimized)
                }

                // keys and kinds of the model's entries, in order (the layout below is computed from them)
                property var info: ({ kinds: [], keys: [], aspects: [] })
                readonly property var kinds: info.kinds
                readonly property var keys: info.keys
                readonly property var aspects: info.aspects

                // an entry's width at rest and without magnification: an icon is square, a minimized window's
                // preview has the window's own proportions (within limits), the divider is a line
                function unitWidth(i) {
                    if (kinds[i] === "divider") return dividerW
                    if (kinds[i] === "minimized" && Theme.dock_minimized_preview)
                        return base * Math.max(0.6, Math.min(2.0, aspects[i] ?? 1))
                    return base
                }

                ListModel { id: dockModel }

                function flat(e) {
                    return { key: e.key, kind: e.kind, name: e.name, icon: e.icon,
                             commandJson: JSON.stringify(e.command), addrs: e.addrs.join(","), allAddrs: e.all.join(","),
                             address: e.address, aspect: e.aspect ?? 1, leaving: false }
                }

                function refreshInfo() {
                    const k = [], ks = [], a = []
                    for (let i = 0; i < dockModel.count; i++) {
                        const e = dockModel.get(i)
                        k.push(e.kind)
                        ks.push(e.key)
                        a.push(e.aspect)
                    }
                    info = { kinds: k, keys: ks, aspects: a }
                }

                // Growing and shrinking //

                // An entry that appears grows from nothing, and one that goes away shrinks to nothing before it's
                // dropped, so the dock resizes smoothly instead of snapping. "pres" is each entry's progress
                // (key -> 0..1, missing = 1: fully there); the layout uses it eased.

                property var pres: ({})
                property bool tweening: false
                property bool synced: false
                function ease(p) { return p * p * (3 - 2 * p) }
                function presenceOf(i) { return ease(pres[keys[i]] ?? 1) }

                function stepPresence(dt) {
                    const step = dt / Math.max(0.001, Theme.dock_resize_duration / 1000)
                    const next = Object.assign({}, pres)
                    let moving = false, removed = false
                    for (let i = dockModel.count - 1; i >= 0; i--) {
                        const e = dockModel.get(i)
                        const target = e.leaving ? 0 : 1
                        const cur = next[e.key] ?? 1
                        const v = cur < target ? Math.min(target, cur + step) : Math.max(target, cur - step)
                        if (e.leaving && v <= 0) {
                            dockModel.remove(i)
                            delete next[e.key]
                            removed = true
                            continue
                        }
                        if (v === 1) delete next[e.key]
                        else next[e.key] = v
                        if (v !== target) moving = true
                    }
                    pres = next
                    if (removed) {
                        refreshInfo()
                        mouse.pressedIndex = -1       // indexes shifted under a press
                        updatePointer()
                    }
                    tweening = moving
                }

                FrameAnimation {
                    running: win.tweening
                    onTriggered: win.stepPresence(Math.min(frameTime, 0.05))
                }

                function sync(list) {
                    const first = !synced
                    synced = true

                    // the new order, with the entries that went away kept in it (shrinking out) right after
                    // the entry that preceded them
                    const present = {}
                    const order = list.map(e => { present[e.key] = true; return { key: e.key, data: e } })
                    const before = []
                    for (let i = 0; i < dockModel.count; i++) before.push(dockModel.get(i).key)
                    for (let o = 0; o < before.length; o++) {
                        if (present[before[o]]) continue
                        let at = 0
                        for (let p = o - 1; p >= 0; p--) {
                            const idx = order.findIndex(x => x.key === before[p])
                            if (idx !== -1) { at = idx + 1; break }
                        }
                        order.splice(at, 0, { key: before[o], data: null })
                    }

                    const next = Object.assign({}, pres)
                    for (let i = 0; i < order.length; i++) {
                        const it = order[i]
                        let j = -1
                        for (let k = i; k < dockModel.count; k++)
                            if (dockModel.get(k).key === it.key) { j = k; break }
                        if (j === -1) {
                            dockModel.insert(i, flat(it.data))
                            if (!first) next[it.key] = 0                // grows in
                        } else {
                            if (j !== i) dockModel.move(j, i, 1)
                            if (it.data) dockModel.set(i, flat(it.data))
                            else dockModel.setProperty(i, "leaving", true)
                        }
                    }
                    pres = next
                    mouse.pressedIndex = -1                              // indexes may have shifted under a press
                    refreshInfo()
                    tweening = true                                      // stepPresence settles it and stops itself
                }

                onEntriesChanged: sync(entries)
                Component.onCompleted: sync(entries)

                // Layout and Magnification //

                // "rest": where everything sits without magnification. "live": sizes and positions now.
                // An icon's size depends on how far its resting centre is from "cursorRest", the cursor
                // translated into resting coordinates. Measuring in resting coordinates is what keeps the
                // icons from jittering: the dock widens while it magnifies, so the cursor's own screen
                // position would drift away from the icon it's over.
                property real cursorRest: 0
                property real magnify: overBar ? 100 : 0      // 0..100, eased smoothly (not a spring)
                Behavior on magnify {
                    NumberAnimation {
                        duration: Theme.dock_magnify_duration
                        easing.type: Easing.OutCubic
                    }
                }

                readonly property var rest: {
                    const lefts = [], widths = []
                    let x = 0
                    for (let i = 0; i < kinds.length; i++) {
                        const e = presenceOf(i)
                        const w = unitWidth(i) * e
                        lefts.push(x)
                        widths.push(w)
                        x += w + gap * e
                    }
                    return { lefts: lefts, widths: widths }
                }

                // sizes / fulls: the entry's height and width at full size (what it looks like at rest, with the
                // magnification); widths: the slot it takes in the dock, which opens and closes as it comes and
                // goes (an entry never scales, the dock makes room); pres: the entry's
                // eased presence (0 while it grows in / shrinks out)
                readonly property var live: {
                    const r = rest
                    const amount = Math.max(0, Math.min(1, magnify / 100))
                    const reach = Math.max(1, Theme.dock_magnify_range)
                    const sizes = [], fulls = [], widths = [], lefts = [], pres = []
                    let x = 0, lastGap = 0
                    for (let i = 0; i < kinds.length; i++) {
                        const e = presenceOf(i)
                        let full = unitWidth(i), h = base
                        if (kinds[i] !== "divider") {
                            const d = Math.abs(r.lefts[i] + r.widths[i] / 2 - cursorRest)
                            const f = d < reach ? 0.5 * (1 + Math.cos(Math.PI * d / reach)) : 0
                            const grow = 1 + (mag - 1) * f * amount
                            full *= grow
                            h *= grow
                        }
                        const w = full * e          // the slot: opens and closes as the entry comes and goes
                        lefts.push(x)
                        sizes.push(h)
                        fulls.push(full)
                        widths.push(w)
                        pres.push(e)
                        lastGap = gap * e
                        x += w + lastGap
                    }
                    return { sizes: sizes, fulls: fulls, widths: widths, lefts: lefts, pres: pres, width: Math.max(0, x - lastGap) }
                }

                // Pointer //

                property real mx: 0
                property real my: 0
                property bool overBar: false         // the cursor is on the dock (the magnifying part)
                property int hoveredIndex: -1        // the icon under the cursor
                property int tipIndex: -1            // last hovered icon, kept while the tooltip fades

                // Works out what's under the cursor from the *current* layout. Run on every move, and
                // every frame while the cursor is on the dock, since the layout moves under a still cursor.
                function updatePointer() {
                    if (!mouse.containsMouse || kinds.length === 0 || !shown || dockModel.count !== kinds.length) {
                        overBar = false
                        hoveredIndex = -1
                        return
                    }
                    const p = bar.mapFromItem(scene, mx, my)
                    const L = live
                    const x = p.x - pad
                    overBar = p.x >= 0 && p.x <= bar.width && p.y >= -overflow - tipGap && p.y <= bar.height
                    if (!overBar) {
                        hoveredIndex = -1
                        return
                    }
                    let j = -1
                    for (let i = 0; i < L.widths.length; i++) {
                        if (x >= L.lefts[i] - gap / 2 && x < L.lefts[i] + L.widths[i] + gap / 2) { j = i; break }
                    }
                    if (j < 0) j = x < 0 ? 0 : L.widths.length - 1
                    const frac = L.widths[j] > 0 ? Math.max(0, Math.min(1, (x - L.lefts[j]) / L.widths[j])) : 0
                    cursorRest = rest.lefts[j] + frac * rest.widths[j]

                    // an entry that's growing in or shrinking out can't be clicked: it might be gone, or
                    // be a different window by the time the click lands
                    const settled = !dockModel.get(j).leaving && L.pres[j] >= 1
                    const onIcon = kinds[j] !== "divider" && settled && x >= L.lefts[j] && x <= L.lefts[j] + L.widths[j]
                                   && p.y >= pad + base - L.sizes[j] - pad
                    hoveredIndex = onIcon ? j : -1
                    if (onIcon) tipIndex = j
                }

                FrameAnimation {
                    running: win.overBar
                    onTriggered: win.updatePointer()
                }

                // The Wayland toplevel of a window (what ScreencopyView captures), by its Hyprland address
                function toplevelFor(address) {
                    const list = Hyprland.toplevels.values
                    const a = String(address).replace(/^0x/, "")
                    for (let i = 0; i < list.length; i++)
                        if (String(list[i].address).replace(/^0x/, "") === a) return list[i].wayland
                    return null
                }

                // Actions //

                function hypr(dispatch) { Quickshell.execDetached(["hyprctl", "dispatch", dispatch]) }

                function launch(entry) {
                    const cmd = JSON.parse(entry.commandJson)
                    if (cmd.length > 0) Quickshell.execDetached(cmd)
                }

                function activate(index, button) {
                    const e = dockModel.get(index)
                    if (!e) return

                    if (button === Qt.MiddleButton) {
                        // close every window of the app (a minimized window: just that one)
                        const all = e.kind === "minimized" ? [e.address] : (e.allAddrs === "" ? [] : e.allAddrs.split(","))
                        for (let i = 0; i < all.length; i++)
                            hypr("hl.dsp.window.close({ window = 'address:" + all[i] + "' })")
                        return
                    }
                    if (e.kind === "minimized") {
                        if (button === Qt.LeftButton) hypr("function() Minimize.restore('" + e.address + "') end")
                        return
                    }
                    if (button === Qt.RightButton) {       // a new window of the app
                        launch(e)
                        return
                    }
                    const addrs = e.addrs === "" ? [] : e.addrs.split(",")
                    if (addrs.length === 0) {
                        // Nothing on screen. If the app's windows are minimized, bring one back: launching
                        // again would do nothing for an app that won't open a second copy (Telegram, the
                        // Calculator, ...), since as far as it knows it's already open. (A new window of an
                        // app that can: right click.)
                        const minimized = e.allAddrs === "" ? [] : e.allAddrs.split(",")
                        if (minimized.length > 0) hypr("function() Minimize.restore('" + minimized[0] + "') end")
                        else launch(e)
                        return
                    }
                    // running: focus it, or its next window when one of them already has the focus
                    const at = addrs.indexOf(HyprEvents.activeAddress)
                    const next = addrs[(at + 1) % addrs.length]
                    hypr("hl.dsp.focus({ window = 'address:" + next + "' })")
                }

                // Input region //

                // The surface is as wide as the screen but most of it is empty: only the dock itself and a thin
                // strip along the bottom edge (the trigger that brings a hidden dock up) take input.
                Item {
                    id: strip
                    x: 0
                    y: scene.height - Theme.dock_trigger_height
                    width: scene.width
                    height: Theme.dock_trigger_height
                }

                Item {
                    id: barHit
                    // reaches up to where magnified icons do, but only while the cursor is on the dock: the
                    // empty band above it shouldn't swallow clicks meant for the windows behind
                    readonly property real extra: mouse.containsMouse ? win.overflow + win.tipGap : 0
                    x: bar.x
                    width: win.shown ? bar.width : 0
                    height: win.shown ? Theme.dock_margin_bottom + win.barH + extra : 0
                    y: scene.height - height
                }

                mask: Region {
                    item: barHit
                    regions: [ Region { item: strip } ]
                }

                // Scene //
                Item {
                    id: scene
                    anchors.fill: parent

                    function applyState() {
                        bar.anchors.bottomMargin = win.shown ? Theme.dock_margin_bottom : bar.hiddenMargin
                    }
                    Component.onCompleted: Qt.callLater(applyState)   // after construction: the margin animates in

                    // The wallpaper as awww shows it (screen-sized, centre-cropped), placed at its on-screen
                    // position in this window. Only a texture source for the icons' frosted glass (the same as
                    // the desktop icons'; ThemedIcon adds the glass + rim when tinted icons have a wallpaper).
                    Image {
                        id: wallImg
                        x: 0
                        y: scene.height - win.modelData.height
                        width: win.modelData.width
                        height: win.modelData.height
                        source: Theme.tintDesktopIcons ? Wallpaper.urlFor(win.modelData.name) : ""
                        sourceSize: Qt.size(width / 2, height / 2)
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: win.hoveredIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        property int pressedIndex: -1

                        onContainsMouseChanged: {
                            win.hovering = containsMouse
                            win.updatePointer()
                        }
                        onPositionChanged: mouse => {
                            win.mx = mouse.x
                            win.my = mouse.y
                            win.updatePointer()
                        }
                        onPressed: mouse => {
                            win.mx = mouse.x
                            win.my = mouse.y
                            win.updatePointer()
                            pressedIndex = win.hoveredIndex
                        }
                        onReleased: mouse => {
                            const released = win.hoveredIndex
                            if (pressedIndex >= 0 && released === pressedIndex) win.activate(released, mouse.button)
                            pressedIndex = -1
                        }
                        onCanceled: pressedIndex = -1
                    }

                    Rectangle {
                        id: bar
                        width: win.live.width + 2 * win.pad
                        height: win.barH
                        radius: Theme.dock_radius
                        color: Qt.rgba(Theme.background1.r, Theme.background1.g, Theme.background1.b, Theme.dock_opacity)

                        readonly property real hiddenMargin: -(height + win.shadowPad + 10)
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: hiddenMargin   // initial value, not animated

                        // slides the way the OSDs do
                        Behavior on anchors.bottomMargin {
                            SpringAnimation {
                                id: slideAnim
                                spring: Theme.springStiffness
                                damping: Theme.springDamping
                                mass: Theme.springMass
                                epsilon: Theme.springEpsilon
                            }
                        }

                        // The textures behind the rim follow the dock's width, which changes with every frame of
                        // the magnification: stepped sizes, so they aren't reallocated every frame. (A texture
                        // size that differs a little from the item's only changes the resolution.)
                        readonly property size texSize: Qt.size(Math.ceil(width / 64) * 64 * 4, Math.ceil(height / 8) * 8 * 4)

                        // Drop shadow (Theme.shadow_*), behind the dock and following it. Cut out under the dock
                        // itself: the dock is translucent, so a shadow showing through would grey it.
                        Item {
                            id: barShadow
                            readonly property real pad: win.shadowPad
                            z: -1
                            x: -pad
                            y: -pad
                            width: bar.width + 2 * pad
                            height: bar.height + 2 * pad

                            RectangularShadow {
                                x: barShadow.pad
                                y: barShadow.pad
                                width: bar.width
                                height: bar.height
                                radius: bar.radius
                                blur: Theme.shadow_blur * Theme.shadow_blur_max
                                offset: Qt.vector2d(0, Theme.shadow_offset)
                                color: Theme.shadow_color
                            }

                            // the dock's shape, 1 px smaller so the mask's soft edge falls under the dock
                            Item {
                                id: barShadowHole
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true
                                Rectangle {
                                    x: barShadow.pad + 1
                                    y: barShadow.pad + 1
                                    width: bar.width - 2
                                    height: bar.height - 2
                                    radius: bar.radius - 1
                                }
                            }

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskInverted: true
                                maskSource: barShadowHole
                            }
                        }

                        // Glass rim
                        Rectangle {
                            id: rimShape
                            anchors.fill: parent
                            radius: bar.radius
                            visible: false
                            layer.enabled: true
                            layer.smooth: true
                            layer.textureSize: bar.texSize
                        }

                        ShaderEffect {
                            anchors.fill: parent
                            property variant source: rimShape
                            property size texel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
                            property real rimPx: Theme.rim_width
                            property real strength: Theme.rim_opacity
                            fragmentShader: Qt.resolvedUrl("../Widgets/shaders/glass_rim.frag.qsb")
                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true
                            layer.textureSize: bar.texSize
                        }

                        // Icons //

                        Item {
                            id: row
                            x: win.pad
                            y: win.pad
                            width: win.live.width
                            height: win.base

                            Repeater {
                                model: dockModel

                                Item {
                                    id: cell
                                    required property int index
                                    required property string key
                                    required property string kind
                                    required property string name
                                    required property string icon
                                    required property string addrs
                                    required property string allAddrs
                                    required property string address

                                    readonly property bool isDivider: kind === "divider"
                                    readonly property bool running: kind === "app" && addrs !== ""
                                    readonly property bool minimized: kind === "minimized"
                                    readonly property real size: win.live.sizes[index] ?? win.base
                                    readonly property real presence: win.live.pres[index] ?? 1
                                    readonly property real fullW: win.live.fulls[index] ?? win.base
                                    readonly property bool hovered: win.hoveredIndex === index
                                    readonly property bool pressed: hovered && mouse.pressedIndex === index

                                    x: win.live.lefts[index] ?? 0
                                    width: win.live.widths[index] ?? win.base
                                    height: isDivider ? win.base * 0.6 : size
                                    y: isDivider ? (win.base - height) / 2 : win.base - size

                                    readonly property real corner: size * Theme.dock_icon_corner

                                    // The entry is laid out at its full size (body) inside a slot (cell.width) that opens and
                                    // closes as it comes and goes: nothing scales, the dock makes room and the entry fades.
                                    // While the slot is not fully open, what lies outside it is clipped, so a half-grown
                                    // entry never sticks out over its neighbours or past the dock's edge. At rest nothing is
                                    // clipped (the glow, the badge and the press scale reach past the cell), and the slot
                                    // reaches a full icon above and below, so only the sides are ever cut.
                                    Item {
                                        id: slot
                                        x: 0
                                        y: -win.maxIcon
                                        width: cell.width
                                        height: cell.height + 2 * win.maxIcon
                                        clip: cell.presence < 1

                                        Item {
                                            id: body
                                            x: 0
                                            y: win.maxIcon
                                            width: cell.fullW
                                            height: cell.height

                                            // divider before the minimized windows
                                            Rectangle {
                                                visible: cell.isDivider
                                                opacity: cell.presence
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 1
                                                height: parent.height
                                                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3)
                                            }

                                            // glow, icon and border together: hover grows them, press shrinks them, and
                                            // release springs back up (as the desktop icons)
                                            Item {
                                                id: content
                                                anchors.fill: parent
                                                visible: !cell.isDivider
                                                opacity: cell.presence
                                                transformOrigin: Item.Bottom
                                                scale: cell.pressed ? 0.9 : 1
                                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                            // glow of a running app
                                            RectangularShadow {
                                                anchors.fill: parent
                                                visible: opacity > 0
                                                opacity: cell.running ? 1 : 0
                                                radius: cell.corner
                                                blur: Theme.dock_glow_blur
                                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.dock_glow_opacity)
                                                Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
                                            }

                                            // The icon is laid out at its largest size and scaled down: resizing it would
                                            // reallocate its shader textures on every frame of the magnification.
                                            ThemedIcon {
                                                visible: !cell.isDivider && !preview.ready
                                                width: win.maxIcon
                                                height: win.maxIcon
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                transformOrigin: Item.Bottom
                                                scale: cell.size / win.maxIcon
                                                supersample: 3
                                                source: cell.isDivider ? "" : AppIcons.resolve(cell.icon)
                                                sourceSize: Qt.size(win.maxIcon * 2, win.maxIcon * 2)
                                                appName: cell.icon
                                                wallpaper: wallImg

                                                // hover: lighter, press: darker (as the desktop icons); the layer is rendered at
                                                // twice the size so the icon stays sharp when it's scaled
                                                layer.enabled: !cell.isDivider
                                                layer.smooth: true
                                                layer.textureSize: Qt.size(width * 2, height * 2)
                                                layer.effect: MultiEffect {
                                                    brightness: cell.pressed ? (Theme.tintDesktopIcons ? -0.1 : -0.35) : (cell.hovered ? 0.1 : 0)
                                                    Behavior on brightness { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                                                }
                                            }

                                            // A minimized window, a snapshot of its contents before it was minimized

                                            Item {
                                                id: preview
                                                readonly property bool wanted: cell.minimized && Theme.dock_minimized_preview
                                                readonly property bool ready: wanted && shot.hasContent
                                                anchors.fill: parent
                                                visible: ready
                                                opacity: ready ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

                                                // A capture asked for right after the window was moved to the hidden workspace fails
                                                // (silently), while one a moment later works. So until a frame has arrived, the view
                                                // is dropped and rebuilt every half second, a few times.
                                                property bool armed: true
                                                property int tries: 0
                                                Timer {
                                                    interval: 500
                                                    repeat: true
                                                    running: preview.wanted && !shot.hasContent && preview.tries < 6
                                                    onTriggered: {
                                                        preview.tries++
                                                        preview.armed = false
                                                        preview.armed = true
                                                    }
                                                }

                                                // the snapshot's size: as large as fits in the cell, in the window's own proportions
                                                readonly property real fit: shot.sourceSize.width > 0 && shot.sourceSize.height > 0
                                                    ? Math.min(width / shot.sourceSize.width, height / shot.sourceSize.height) : 0

                                                Item {
                                                    id: shotBox
                                                    anchors.centerIn: parent
                                                    width: shot.sourceSize.width * preview.fit
                                                    height: shot.sourceSize.height * preview.fit
                                                    layer.enabled: preview.ready
                                                    layer.smooth: true
                                                    layer.effect: MultiEffect {
                                                        maskEnabled: true
                                                        maskSource: shotMask
                                                        brightness: cell.pressed ? -0.1 : (cell.hovered ? 0.1 : 0)
                                                        Behavior on brightness { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                                                    }

                                                    // Solid backing: the capture keeps a window's transparency (a translucent
                                                    // terminal, say), which would let the dock's glass show through the thumbnail.
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1)
                                                    }

                                                    ScreencopyView {
                                                        id: shot
                                                        anchors.fill: parent
                                                        live: false
                                                        captureSource: preview.wanted && preview.armed ? win.toplevelFor(cell.address) : null
                                                    }
                                                }

                                                // rounded corners for the snapshot
                                                Rectangle {
                                                    id: shotMask
                                                    anchors.fill: shotBox
                                                    radius: cell.corner
                                                    visible: false
                                                    layer.enabled: true
                                                }

                                                // Glass rim

                                                readonly property size rimTex: Qt.size(Math.ceil(shotBox.width / 16) * 16 * 4,
                                                                                       Math.ceil(shotBox.height / 16) * 16 * 4)
                                                Rectangle {
                                                    id: thumbRimShape
                                                    anchors.fill: shotBox
                                                    radius: cell.corner
                                                    visible: false
                                                    layer.enabled: preview.ready
                                                    layer.smooth: true
                                                    layer.textureSize: preview.rimTex
                                                }
                                                ShaderEffect {
                                                    anchors.fill: shotBox
                                                    visible: preview.ready
                                                    property variant source: thumbRimShape
                                                    property size texel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
                                                    property real rimPx: Theme.wide_rim_width
                                                    property real strength: Theme.wide_rim_opacity
                                                    property real reach: Theme.wide_rim_reach / 2
                                                    fragmentShader: Qt.resolvedUrl("../Widgets/shaders/wide_glass_rim.frag.qsb")
                                                    layer.enabled: preview.ready
                                                    layer.smooth: true
                                                    layer.mipmap: true
                                                    layer.textureSize: preview.rimTex
                                                }

                                                // the app's icon, bottom right. Laid out at its full size and scaled (like the
                                                // main icons, so its shaders aren't reallocated while the dock magnifies).
                                                Item {
                                                    width: win.maxIcon * 0.46
                                                    height: width
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.rightMargin: -cell.size * 0.08
                                                    anchors.bottomMargin: -cell.size * 0.08
                                                    transformOrigin: Item.BottomRight
                                                    scale: cell.size / win.maxIcon

                                                    ThemedIcon {
                                                        anchors.fill: parent
                                                        supersample: 3
                                                        source: preview.wanted ? AppIcons.resolve(cell.icon) : ""
                                                        sourceSize: Qt.size(width * 2, height * 2)
                                                        appName: cell.icon
                                                        wallpaper: wallImg
                                                    }
                                                }
                                            }

                                            // border of a running app, in the accent colour
                                            Rectangle {
                                                anchors.fill: parent
                                                visible: opacity > 0
                                                opacity: cell.running ? 1 : 0
                                                color: "transparent"
                                                radius: cell.corner
                                                border.width: Theme.dock_glow_width
                                                border.color: Theme.accent
                                                Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
                                            }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Name of the hovered icon
                        Rectangle {
                            id: tip
                            readonly property int i: win.tipIndex
                            readonly property real iconSize: win.live.sizes[i] ?? win.base
                            readonly property string label: i >= 0 && i < dockModel.count ? dockModel.get(i).name : ""
                            visible: opacity > 0
                            opacity: win.hoveredIndex >= 0 && win.shown ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            width: Math.min(tipText.implicitWidth, 260) + 20
                            height: win.tipH
                            radius: win.tipH / 2
                            x: win.pad + (win.live.lefts[i] ?? 0) + (win.live.widths[i] ?? win.base) / 2 - width / 2
                            y: win.pad + win.base - iconSize - win.tipGap - height
                            color: Qt.rgba(Theme.background1.r, Theme.background1.g, Theme.background1.b, Theme.dock_opacity)

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                width: parent.width - 20
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: tip.label
                                color: Theme.text
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
} 