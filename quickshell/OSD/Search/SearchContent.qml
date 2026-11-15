import Quickshell
import QtQuick
import QtQuick.Effects
import "../../Theme"
import "../../Utils"

// The search card: a bar that grows a list of applications below it when the query isn't empty.
// Matches the names, generic names, keywords (the desktop entries' aliases) and ids of the
// installed applications. Every match is in the list, but the list is `maxVisible` rows tall:
// the rest is scrolled to (arrow keys / wheel)

Item {
    id: root
    signal closeRequested()

    readonly property int maxVisible: 6     // rows shown at once; more results scroll
    readonly property int cardWidth: 680
    readonly property int barHeight: 56
    readonly property int rowHeight: 52
    readonly property int listPad: 8
    readonly property int cardRadius: 28
    // room for the drop shadow (Theme.shadow_*) around the card
    readonly property real shadowPad: Theme.shadow_blur * Theme.shadow_blur_max + Math.abs(Theme.shadow_offset)

    property string query: ""
    property int selected: 0
    readonly property bool expanded: query.trim() !== ""
    readonly property var results: expanded ? search(query.trim().toLowerCase()) : []
    onResultsChanged: selected = 0

    // Searching

    // how well q matches the text t (both lower case): 0 = not at all
    function textScore(t, q) {
        if (!t) return 0
        if (t === q) return 100
        if (t.startsWith(q)) return 90
        var i = t.indexOf(q)
        if (i < 0) return 0
        // start of a later word ("studio" in "visual studio code") beats a match in the middle of onez
        return /[\s\-_.]/.test(t.charAt(i - 1)) ? 75 : 55
    }

    function entryScore(e, q) {
        var name = (e.name || "").toLowerCase()
        var best = textScore(name, q)

        // initials: "vsc" -> Visual Studio Code
        var initials = name.split(/[\s\-_.]+/).map(w => w.charAt(0)).join("")
        if (q.length > 1 && initials.startsWith(q)) best = Math.max(best, 65)

        // aliases rank below the name itself
        var alias = Math.max(
            textScore((e.genericName || "").toLowerCase(), q),
            textScore((e.id || "").toLowerCase(), q))
        var kw = e.keywords || []
        for (var i = 0; i < kw.length; i++) alias = Math.max(alias, textScore(kw[i].toLowerCase(), q))
        return Math.max(best, alias * 0.6)
    }

    function search(q) {
        var apps = DesktopEntries.applications.values, scored = []
        for (var i = 0; i < apps.length; i++) {
            if (apps[i].noDisplay) continue
            var s = entryScore(apps[i], q)
            if (s > 0) scored.push({ entry: apps[i], score: s, name: apps[i].name || "" })
        }
        scored.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
        return scored.map(r => r.entry)
    }

    function launch(e) {
        if (!e) return
        if (e.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(e.command))
        else e.execute()
        closeRequested()
    }

    function move(delta) {
        if (results.length > 0) selected = (selected + delta + results.length) % results.length
    }

    // Layout

    // The list's height when open: the visible rows (one row's worth for "no results"), padding and
    // the divider. listShown is its spring-animated counterpart, 0 while closed.
    readonly property int visibleRows: Math.min(maxVisible, Math.max(1, results.length))
    readonly property real listHeight: visibleRows * rowHeight + 2 * listPad + 1
    property real listShown: expanded ? listHeight : 0
    // how many times faster than the Theme spring the card moves: stiffness scales with the
    // square of the speed and damping with the speed, so the motion is the same, just quicker
    readonly property real animSpeed: 2
    Behavior on listShown {
        SpringAnimation {
            spring:  Theme.springStiffness * root.animSpeed * root.animSpeed
            damping: Theme.springDamping * root.animSpeed
            mass:    Theme.springMass
            epsilon: Theme.springEpsilon
        }
    }

    Item {
        id: card
        width: root.cardWidth
        // the spring overshoots, and it must never cut into the bar when closing
        height: root.barHeight + Math.max(0, root.listShown)
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.28)

        // Drop shadow
        Item {
            id: shadow
            x: -root.shadowPad
            y: -root.shadowPad
            width: card.width + 2 * root.shadowPad
            height: card.height + 2 * root.shadowPad

            RectangularShadow {
                x: root.shadowPad
                y: root.shadowPad
                width: card.width
                height: card.height
                radius: root.cardRadius
                blur: Theme.shadow_blur * Theme.shadow_blur_max
                offset: Qt.vector2d(0, Theme.shadow_offset)
                color: Theme.shadow_color
            }

            // the card's shape, cut out of the shadow
            // 1 px smaller so the mask's soft edge falls under 
            // the card instead of leaving a light seam around it
            Item {
                id: shadowHole
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    x: root.shadowPad + 1
                    y: root.shadowPad + 1
                    width: card.width - 2
                    height: card.height - 2
                    radius: root.cardRadius - 1
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: shadowHole
            }
        }

        // Background
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: root.cardRadius
            color: Qt.rgba(Theme.background1.r, Theme.background1.g, Theme.background1.b, 0.68)
        }

        // glass rim drawn from a hidden copy of the card's shape
        // supersampled so it's anti-aliased
        Rectangle {
            id: rimShape
            anchors.fill: parent
            radius: root.cardRadius
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 4, height * 4)
        }

        ShaderEffect {
            anchors.fill: parent
            property variant source: rimShape
            property size texel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
            property real rimPx: Theme.wide_rim_width
            property real strength: Theme.wide_rim_opacity
            property real reach: Theme.wide_rim_reach / 2
            fragmentShader: Qt.resolvedUrl("../../Widgets/shaders/glass_rim.frag.qsb")
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(width * 4, height * 4)
        }

        // swallows clicks on the card, so they don't reach the click-outside-to-close area
        MouseArea { anchors.fill: parent }

        // Search bar

        Item {
            id: bar
            width: parent.width
            height: root.barHeight

            Text {
                id: glyph
                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                text: ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: Qt.darker(Theme.text, 1.3)
            }

            TextInput {
                id: input

                anchors {
                    left: glyph.right; leftMargin: 14
                    right: parent.right; rightMargin: 22
                    verticalCenter: parent.verticalCenter
                }

                focus: true
                clip: true
                color: Theme.text
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                font.family: "Inter"
                font.pixelSize: 20
                cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.text }
                text: root.query
                onTextChanged: root.query = text

                Text {
                    visible: input.text === ""
                    text: "Search"
                    color: Qt.darker(Theme.text, 2)
                    font: input.font
                }

                Keys.onPressed: event => {
                    var ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) root.closeRequested()
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                             || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) root.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                             || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) root.move(-1)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.launch(root.results[root.selected])
                    else return
                    event.accepted = true
                }

                Component.onCompleted: forceActiveFocus()
            }
        }

        // Results

        // The card's height is what's animated: this window just uncovers / covers the list, which
        // itself never moves or resizes with the animation.

        Item {
            y: root.barHeight
            width: parent.width
            height: Math.max(0, root.listShown)
            clip: true

            // Divider 
            Rectangle {
                x: 16; width: parent.width - 32; height: 1
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
            }

            Text {
                visible: root.results.length === 0
                x: 0; y: root.listPad + 1
                width: parent.width; height: root.rowHeight
                text: "No applications found"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Qt.darker(Theme.text, 1.5)
                font.family: "Inter"
                font.pixelSize: 14
            }

            ListView {
                id: list
                x: root.listPad
                y: root.listPad + 1
                width: parent.width - 2 * root.listPad
                height: root.visibleRows * root.rowHeight
                clip: true
                model: root.results
                currentIndex: root.selected
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                // arrow keys move root.selected; keep that row in view
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                // a new search starts at the top
                onModelChanged: positionViewAtBeginning()

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 18 + root.listPad / 2
                        visible: row.index === root.selected
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.14)
                    }

                    Image {
                        id: icon
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 32; height: 32
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        source: AppIcons.lookup(row.modelData.icon) || AppIcons.lookup(row.modelData.id)
                    }

                    Column {
                        anchors {
                            left: icon.right; leftMargin: 14
                            right: parent.right; rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: "Inter"
                            font.pixelSize: 14
                            font.weight: 500
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.genericName || row.modelData.comment || ""
                            elide: Text.ElideRight
                            color: Qt.darker(Theme.text, 1.6)
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: root.selected = row.index
                        onClicked: root.launch(row.modelData)
                    }
                }
            }
        }
    }
}
