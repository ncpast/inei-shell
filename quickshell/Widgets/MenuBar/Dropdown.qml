import Quickshell
import QtQuick
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Wayland
import "../../Theme"
import "../../Utils"
import ".."

PanelWindow {
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        Shortcut {
            sequence: "Escape"
            enabled: root.systemMenuOpen
            onActivated: {
                root.systemMenuOpen = false
                root.menuOpen = ""
            }
        }

        id: systemPopup
        visible: root.systemMenuOpen && root.systemAnchorItem !== null && root.menuOpen === category

        anchors.top: true
        anchors.left: true

        implicitWidth: 200
        implicitHeight: menuColumn.implicitHeight //+ (Theme.button_radius * 2)

        margins.top: -1
        margins.left: popupX - (Theme.leftBarHidden ? 0 : Theme.left_panel_width)

        color: "transparent"

        Rectangle {
            id: buttonWrapper
            opacity: root.systemMenuOpen && root.systemAnchorItem !== null ? 1 : 0
            anchors.fill: parent
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8)
            radius: Theme.button_radius
            //border.color: Theme.border
            //border.width: 1

            // wide liquid glass rim (Widgets/shaders/wide_glass_rim.frag) around the menu, drawn from a
            // hidden copy of its shape; supersampled so it's anti-aliased. Declared before the rows, so
            // the hover highlights draw over it.
            Rectangle {
                id: rimShape
                anchors.fill: parent
                radius: buttonWrapper.radius
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
                fragmentShader: Qt.resolvedUrl("../shaders/wide_glass_rim.frag.qsb")
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                layer.textureSize: Qt.size(width * 4, height * 4)
            }

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                //anchors.topMargin: Theme.button_radius
                //anchors.bottomMargin: Theme.button_radius
                spacing: 2

                Repeater {
                    model: content
                    id: systemRepeater

                    Rectangle {
                        property var item: root.systemMenuItems[modelData] || root.trayPrograms[modelData] || {}
                        property var isSubmenu: item.type === "submenu" 
                        property bool itemEnabled: {
                            if (item.label === "Dock" || item.type === "info")
                                return false
                            if (!item.requirements) 
                                return true
                            if (item.requirements.attribute === "floating")
                                return root.activeWindowFloating
                            return true
                        }

                        id: choiceRoot
                        width: menuColumn.width
                        implicitHeight: modelData != "br" ? choiceLabel.implicitHeight + 10 : 6
                        color: Qt.rgba(1, 1, 1, choiceMouseArea.containsMouse && itemEnabled ? 0.1 : 0)

                        topLeftRadius: index == 0 ? Theme.button_radius : 0
                        topRightRadius: index == 0 ? Theme.button_radius : 0
                        bottomLeftRadius: index == systemRepeater.count - 1 ? Theme.button_radius : 0
                        bottomRightRadius: index == systemRepeater.count - 1 ? Theme.button_radius : 0

                        Behavior on color {
                            ColorAnimation { duration: Theme.colorChangeAnimDuration / 2 }
                        }

                        
                        Rectangle {
                            visible: modelData === "br"
                            opacity: 0.4
                            color: Theme.border
                            height: 1
                            width: parent.width - 25
                            anchors.centerIn: parent
                        }

                        RowLayout {
                            visible: modelData != "br"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 15
                            anchors.rightMargin: 10
                            spacing: 8

                            // tray programs: the program's own tray icon, its white parts tinted to Theme.text
                            MonoTintIcon {
                                visible: item.type === "trayitem"
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: item.type === "trayitem" ? item.icon : ""
                            }

                            Text {
                                opacity: itemEnabled ? 1 : 0.6
                                text: item.icon || ''
                                font.pixelSize: 10
                                color: Theme.text
                                //Layout.preferredWidth: 10
                                visible: item.icon !== undefined && item.type !== "trayitem"
                                Layout.fillHeight: true
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                opacity: itemEnabled ? 1 : 0.6
                                font.weight: Font.Medium
                                id: choiceLabel
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: Text.AlignVCenter
                                text: item.label + (item.toggled ? '  ' : '') || ''
                                color: Theme.text
                                font.pixelSize: 13
                                font.family: "Inter"
                            }

                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.fillHeight: true
                                color: "transparent"

                                Text {
                                    opacity: isSubmenu ? 1 : 0.3
                                    font.weight: Font.Medium
                                    text: {
                                        if (isSubmenu) return ""
                                        if (!hyprBinds.loaded) return ""
                                        if (!item || item.shortcut === undefined) return ""
                                        return hyprBinds.shortcutFor(item.shortcut || "")
                                    }
                                    font.pixelSize: 14
                                    color: Theme.text

                                    anchors.right: parent.right
                                    anchors.bottom: isSubmenu ? undefined : parent.bottom 
                                    anchors.verticalCenter: isSubmenu ? parent.verticalCenter : undefined
                                }
                            }
                        }

                        MouseArea {
                            visible: modelData != "br"
                            id: choiceMouseArea
                            anchors.fill: parent
                            hoverEnabled: itemEnabled
                            cursorShape: itemEnabled ? Qt.PointingHandCursor : undefined
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: event => {
                                if (!itemEnabled) return;
                                if (event.button === Qt.RightButton) {
                                    // right click only does something for entries that define it (tray programs: quit)
                                    if (!item.rightclickaction) return;
                                    item.rightclickaction();
                                } else if (item.type == "command" && item.action)
                                    Quickshell.execDetached(item.action);
                                else if ((item.type == "setter" || item.type == "trayitem") && item.action)
                                    item.action();
                                root.systemMenuOpen = false
                                root.menuOpen = ""
                            }
                        }
                    }
                }
            }
        }
    }