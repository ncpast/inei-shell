import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "../Theme"
import "../Utils"
import "../Widgets"

// Desktop icons: one layer-shell window per monitor on the lowest (Background) layer,
// so they sit under every window. Mapped only while that monitor's active workspace
// has no windows; Hyprland fades the layer in and out.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        // Only as big as the block of grid cells the icons actually occupy. A full-screen
        // transparent surface that fades is expensive for the compositor (it re-composites
        // the whole screen for every frame of the fade); this window covers only a fraction of the screen.
        // Grid geometry is computed from the screen minus the bars, so cells are identical to
        // the old full-area layout.
        readonly property real insetTop: Theme.top_panel_height
        readonly property real insetLeft: Theme.leftBarHidden ? 0 : Theme.left_panel_width
        readonly property real insetRight: Theme.leftBarHidden ? 0 : Theme.spacer_panel_size
        readonly property real insetBottom: Theme.leftBarHidden ? 0 : Theme.spacer_panel_size
        readonly property real cellW: (modelData.width - insetLeft - insetRight) / DesktopIcons.columns
        readonly property real cellH: (modelData.height - insetTop - insetBottom) / DesktopIcons.rows

        readonly property var cells: {
            var minX = DesktopIcons.columns, maxX = -1, minY = DesktopIcons.rows, maxY = -1
            for (var i = 0; i < DesktopIcons.items.length; i++) {
                var it = DesktopIcons.items[i]
                if (it.x < 0 || it.x >= DesktopIcons.columns || it.y < 0 || it.y >= DesktopIcons.rows) continue
                minX = Math.min(minX, it.x); maxX = Math.max(maxX, it.x)
                minY = Math.min(minY, it.y); maxY = Math.max(maxY, it.y)
            }
            if (maxX < 0) return { minX: 0, minY: 0, cols: 1, rows: 1 }
            return { minX: minX, minY: minY, cols: maxX - minX + 1, rows: maxY - minY + 1 }
        }

        anchors { top: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        margins.left: insetLeft + cells.minX * cellW
        margins.top: insetTop + cells.minY * cellH
        implicitWidth: cells.cols * cellW
        implicitHeight: cells.rows * cellH
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-desktop"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property var workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
        readonly property bool workspaceEmpty: workspace !== null
                                            && !HyprEvents.workspaceApps[workspace.id]

        // Mapped only while this monitor's workspace is empty. Hyprland fades the layer surface in
        // and out itself when it maps / unmaps (layer rule in ~/.config/hypr/modules/windowrules.lua,
        // fadeLayersIn / fadeLayersOut in modules/visual.lua), so there is no fade logic here.
        //
        // The map waits until everything is loaded (wallpaper texture for the glass, every icon),
        // so the first frame Hyprland fades in is complete instead of icons popping in one by one.
        // The items load while the window is unmapped. Safety net: if that hasn't finished after
        // loadTimeout ms, show anyway.
        visible: workspaceEmpty && (loadedOnce || loadTimedOut)

        property int readyTick: 0               // bumped whenever an icon finishes loading; re-evaluates iconsReady
        readonly property bool iconsReady: {
            readyTick
            for (var i = 0; i < iconRepeater.count; i++) {
                var it = iconRepeater.itemAt(i)
                if (!it || !it.iconDone) return false
            }
            return true
        }
        readonly property bool wallReady: !Theme.tintDesktopIcons || wallImg.source.toString() === ""
                                          || wallImg.status === Image.Ready || wallImg.status === Image.Error
        readonly property bool contentReady: iconsReady && wallReady

        // Latched: showing the window makes the images reload for a moment, and following that
        // would hide it again (a map / unmap loop). Gate only the first map.
        property bool loadedOnce: false
        onContentReadyChanged: if (contentReady) loadedOnce = true

        property bool loadTimedOut: false
        onWorkspaceEmptyChanged: if (!workspaceEmpty) loadTimedOut = false
        Timer {
            interval: 400                       // loadTimeout
            running: win.workspaceEmpty && !win.loadedOnce && !win.loadTimedOut
            onTriggered: win.loadTimedOut = true
        }

        Item {
            id: content
            anchors.fill: parent

            readonly property real cellW: win.cellW
            readonly property real cellH: win.cellH

            // The wallpaper as awww shows it (screen-sized, centre-cropped), placed at its on-screen
            // position relative to this window. Only a texture source for the icons' glass.
            // Loaded at half resolution: it only ever gets blurred.
            Image {
                id: wallImg
                x: -win.margins.left
                y: -win.margins.top
                width: win.modelData.width
                height: win.modelData.height
                source: Theme.tintDesktopIcons ? Wallpaper.urlFor(win.modelData.name) : ""
                sourceSize: Qt.size(width / 2, height / 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: false     // reloaded on every map: must be there on the first frame
                visible: false
            }

            Repeater {
                id: iconRepeater
                model: DesktopIcons.items

                Item {
                    id: cell
                    required property var modelData

                    // icon image finished loading (or has nothing to load / failed)
                    readonly property bool iconDone: themedIcon.source.toString() === ""
                                                  || themedIcon.status === Image.Ready
                                                  || themedIcon.status === Image.Error
                    onIconDoneChanged: win.readyTick++
                    Component.onCompleted: win.readyTick++

                    x: (modelData.x - win.cells.minX) * content.cellW
                    y: (modelData.y - win.cells.minY) * content.cellH
                    width: content.cellW
                    height: content.cellH
                    visible: modelData.x >= 0 && modelData.x < DesktopIcons.columns
                          && modelData.y >= 0 && modelData.y < DesktopIcons.rows

                    Rectangle {
                        id: tile
                        anchors.centerIn: parent
                        width: DesktopIcons.tileWidth
                        height: DesktopIcons.tileHeight
                        radius: Theme.button_radius
                        color: "transparent"

                        Column {
                            id: iconColumn
                            anchors.centerIn: parent
                            width: parent.width - 8
                            spacing: 6

                            Item {
                                id: iconItem
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: DesktopIcons.iconSize
                                height: DesktopIcons.iconSize
                                readonly property url src: AppIcons.resolve(cell.modelData.icon)
                                readonly property bool tinted: Theme.tintDesktopIcons

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    brightness: mouse.pressed ? (Theme.tintDesktopIcons ? -0.1 : -0.35) : (mouse.containsMouse ? 0.1 : 0)
                                    Behavior on brightness { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
                                    shadowEnabled: true
                                    shadowColor: Theme.shadow_color
                                    shadowBlur: Theme.shadow_blur
                                    blurMax: Theme.shadow_blur_max
                                    shadowVerticalOffset: Theme.shadow_offset
                                }

                                // hover: grow, press: shrink, release: spring back up
                                scale: mouse.pressed ? 0.95 : (mouse.containsMouse ? 1.05 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                // The icon: normal / dark / tinted, with frosted glass + rim when tinted
                                // (Widgets/ThemedIcon.qml)
                                ThemedIcon {
                                    id: themedIcon
                                    anchors.fill: parent
                                    asyncLoad: false
                                    source: iconItem.src
                                    sourceSize: Qt.size(DesktopIcons.iconSize * 4, DesktopIcons.iconSize * 4)
                                    appName: cell.modelData.icon
                                    wallpaper: wallImg
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.modelData.name
                                color: Theme.text
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: "Inter"
                                font.weight: 500

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: Theme.text_shadow_color
                                    shadowBlur: Theme.text_shadow_blur
                                    blurMax: Theme.text_shadow_blur_max
                                    shadowVerticalOffset: Theme.text_shadow_offset
                                }
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(cell.modelData.command)
                        }
                    }
                }
            }
        }
    }
}
