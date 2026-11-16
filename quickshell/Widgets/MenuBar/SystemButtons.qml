import Quickshell
import QtQuick
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../../Theme"
import "../../Utils"

Row {
    id: root
    spacing: 5
    anchors.verticalCenter: parent.verticalCenter

    property bool systemMenuOpen: false
    property bool activeWindowFloating: false
    property string menuOpen: ""
    property var systemAnchorItem: null
    property real popupX: 0
    property real popupY: 0
    property real buttonWidth: 0
    property bool autofloatEnabled: false

    //SystemEvents {}

    FileView {
        id: autofloatFile
        path: Quickshell.env("HOME") + "/.config/hypr/bool/autofloat-enabled.lua"

        onLoaded: {
            root.autofloatEnabled = this.text().includes("true")
        }
    }

    // VVV Rewrite this for all to be in a monolithic file VVV

    Process {
        id: activeWindowCheck
        command: ["hyprctl", "activewindow", "-j"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    root.activeWindowFloating = data.floating === true
                } catch (e) {
                    root.activeWindowFloating = false
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activewindow" || event.name === "changefloatingmode") {
                activeWindowCheck.running = true
            }
        }
    }

    // Tray items // 

    readonly property var hiddenTrayPrograms: ["udiskie"]
    function isHiddenTray(item) {
        var key = ((item.id || "") + " " + (item.title || "")).toLowerCase()
        for (var i = 0; i < hiddenTrayPrograms.length; i++)
            if (key.indexOf(hiddenTrayPrograms[i]) !== -1) return true
        return false
    }

    readonly property var trayItems: SystemTray.items.values.filter(item => !root.isHiddenTray(item))

    // One menu opener per tray item, kept alive so the item's menu entries are loaded by the time
    // it is right-clicked (closeTrayProgram looks for a "Quit" entry in them).
    Instantiator {
        id: trayOpeners
        model: ScriptModel { values: root.trayItems }
        delegate: QsMenuOpener {
            required property var modelData
            property var trayItem: modelData
            menu: modelData.menu
        }
    }

    // Quit a tray app: prefer its own "Quit"/"Exit" menu entry (a graceful quit that works even
    // when the app has no window, e.g. minimised to tray); otherwise ask Hyprland to close a
    // window whose class matches the tray id.
    function closeTrayProgram(item) {
        var opener = null
        for (var k = 0; k < trayOpeners.count; k++) {
            var o = trayOpeners.objectAt(k)
            if (o && o.trayItem === item) { opener = o; break }
        }
        var entries = opener && opener.children ? opener.children.values : []
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e.isSeparator || !e.enabled) continue
            var label = (e.text || "").replace(/&/g, "")
            if (/^(quit|exit|close)\b|\b(quit|exit)\b/i.test(label)) {
                e.triggered()
                return
            }
        }
        var cls = (item.id || item.title || "").replace(/["\\]/g, "")
        if (cls !== "")
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = \"class:(?i)" + cls + "\" })"])
    }

    function trayProgram(item) {
        return {
            label: AppIcons.displayName(item.id, item.title),
            // the tray item's own icon (white parts tinted to Theme.text by the dropdown); the
            // desktop entry's icon only if the item reports none
            icon: item.icon || AppIcons.lookup(AppIcons.entryFor(item.id) ? AppIcons.entryFor(item.id).id : item.id),
            type: "trayitem",
            action: () => item.activate(),
            rightclickaction: () => root.closeTrayProgram(item)
        }
    }

    readonly property var trayPrograms: {
        var out = {}
        for (var i = 0; i < root.trayItems.length; i++) {
            var item = root.trayItems[i]
            out["tray:" + (item.id || i)] = root.trayProgram(item)
        }
        return out
    }

    readonly property var programsContent: {
        var keys = Object.keys(root.trayPrograms)
        return ["Launcher", "br"].concat(keys.length > 0 ? keys : ["NoPrograms"])
    }

    property var systemMenuItems: ({
        "Launcher": {
            label: "Launcher",
            icon: "\uf002",
            type: "command",
            // the search / app launcher (Hyprland binds SUPER to the same IPC call)
            action: ["qs", "ipc", "call", "search", "toggle"]
        },
        "NoPrograms": {
            label: "No tray programs",
            type: "info"
        },
        "Terminal": {
            label: "Terminal",
            icon: "",
            type: "command",
            // same as SUPER+Q: picks the focus-mode kitty config on a focus-mode workspace
            action: ["hyprctl", "dispatch", "Binds[\"terminal\"]"],
            shortcut: "terminal"
        },
        "File Explorer": {
            label: "File Explorer",
            icon: "",
            type: "command",
            action: ["sh", "-c", "cd ~ && nautilus"],
            shortcut: "file-manager"
        },
        "Preferences": {
            label: "Preferences",
            icon: "",
            type: "command",
            action: ["nwg-look"]
        },
        "Software Center": {
            label: "Software Center",
            icon: "",
            type: "command",
            action: ["plasma-discover"]
        },
        "Sleep": {
            label: "Sleep",
            icon: "󰤄",
            type: "command",
            action: ["/home/siro/.config/hypr/scripts/suspend.sh"]
        },
        "Lock Screen": {
            label: "Lock Screen",
            icon: "",
            type: "command",
            action: ["qs", "ipc", "call", "lock", "lock"],
        },
        "Log Out": {
            label: "Log Out",
            icon: " ",
            type: "command",
            action: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"],
            shortcut: "exit-hyprland"
        },
        "Shut Down": {
            label: "Shut Down",
            icon: "",
            type: "command",
            action: ["systemctl", "poweroff"]
        },
        "Reboot": {
            label: "Reboot",
            icon: "",
            type: "command",
            action: ["systemctl", "reboot"]
        },
        "New Workspace": {
            label: "New",
            icon: "",
            type: "command",
            action: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"empty\" })"],
        },
        "Previous Workspace": {
            label: "Previous",
            icon: "",
            type: "command",
            action: ["hyprctl", "dispatch", "Binds[\"workspace-prev\"]"],
            shortcut: "workspace-prev"
        },
        "Next Workspace": {
            label: "Next",
            type: "command",
            icon: "",
            action: ["hyprctl", "dispatch", "Binds[\"workspace-next\"]"],
            shortcut: "workspace-next"
        },
        "Tiled Workspace": {
            label: "Tile All",
            icon: "󰕮",
            type: "command",
            action: [Quickshell.env("HOME") + "/.config/quickshell/scripts/tileAll.sh"]
        },
        "Floating Workspace": {
            label: "Float All",
            icon: "",
            type: "command",
            action: [Quickshell.env("HOME") + "/.config/quickshell/scripts/floatAll.sh"]
        },
        "Workspace Overview": {
            label: "Overview",
            icon: "󰕯",
            type: "command",
            action: ["hyprctl", "dispatch", "overview:open"]
        },
        "Maximize": {
            label: "Maximize",
            icon: "",
            type: "command",
            action: ["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })"]
        },
        "Fullscreen": {
            label: "Fullscreen",
            icon: "",
            type: "command",
            action: ["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })"]
        },
        "Minimize": {
            label: "Minimize",
            icon: "",
            type: "command",
            action: ["hyprctl", "dispatch", "function() Minimize.active() end"],
            shortcut: "minimize-window"
        },
        "Close Window": {
            label: "Close",
            icon: "󰅙",
            type: "command",
            action: ["hyprctl", "dispatch", "Binds[\"close-window\"]"],
            shortcut: "close-window"
        },
        "Move to New Workspace": {
            label: "To New Workspace",
            type: "command",
            action: ["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = \"empty\" })"],
            shortcut: "workspace-new"
        },
        "Move to Workspace": {
            label: "Move to Workspace...",
            type: "submenu"
        },
        "Pin Window": {
            label: "Pin",
            type: "command",
            icon: " ",
            action: ["hyprctl", "dispatch", "hl.dsp.window.pin()"],
            shortcutDispatcher: "pin",
            requirements: {
                type: "window",
                attribute: "floating"
            }
        },
        "Toggle Floating": {
            label: "Toggle Floating",
            type: "command",
            action: ["hyprctl", "dispatch", "Binds[\"toggle-float\"]"],
            shortcut: "toggle-float"
        },
        "Enable Pseudotiling": {
            label: "Pseudotiling",
            type: "command",
            action: ["hyprctl", "dispatch", "Binds[\"toggle-pseudo\"]"],
            shortcut: "toggle-pseudo"
        },
        "Toggle Dock": {
            label: "Dock",
            icon: "󱂩",
            type: "setter",
            toggled: Theme.dock_enabled,
            action: () => { Theme.dock_enabled = !Theme.dock_enabled }
        },
        "Focus Mode": {
            label: "Focus Mode",
            type: "setter",
            icon: "󰈈",
            toggled: FocusMode.global,
            action: () => { FocusMode.toggleGlobal() }
        },
        "Focused Workspace": {
            label: "Focused Workspace",
            type: "setter",
            icon: "󰈈",
            // local: only the workspace you're on (shows that workspace's own state)
            toggled: FocusMode.isFocused(FocusMode.currentWorkspace),
            action: () => { FocusMode.toggleCurrent() }
        },
        "Automatic Tiling": {
            label: "Automatic Tiling",
            icon: "󰕮",
            type: "setter",
            toggled: !root.autofloatEnabled,
            action: () => {
                root.autofloatEnabled = !root.autofloatEnabled
                Quickshell.execDetached(["sh", "-c",
                    `echo 'return { enabled = ${root.autofloatEnabled} }' > ${Quickshell.env("HOME")}/.config/hypr/bool/autofloat-enabled.lua`
                ])
            }
        },
    })

    Repeater {
        model: ["System", "Workspace", "Window", "View", "Programs"]

        Rectangle {
            id: delegateRoot
            implicitWidth: label.implicitWidth + 10
            implicitHeight: label.implicitHeight + 8
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                (mouseArea.containsMouse && !mouseArea.pressed) 
                || (root.systemMenuOpen && root.menuOpen === modelData && !mouseArea.pressed) ? 1 : 0)
            radius: 4

            Behavior on color {
                ColorAnimation { duration: Theme.colorChangeAnimDuration / 2 }
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData
                color: (mouseArea.containsMouse && !mouseArea.pressed) || (
                    root.systemMenuOpen && root.menuOpen === modelData && !mouseArea.pressed) ?
                    Theme.background : Theme.text
                font.pixelSize: 13
                font.family: "Inter"
                font.weight: modelData === "System" ? Font.Bold : Font.DemiBold
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.menuOpen === modelData) {
                        root.systemMenuOpen = false
                        root.menuOpen = ""
                    } else {
                        root.systemAnchorItem = delegateRoot
                        var pos = delegateRoot.mapToGlobal(0, delegateRoot.height)
                        root.popupX = pos.x
                        root.popupY = pos.y
                        root.buttonWidth = delegateRoot.width
                        root.systemMenuOpen = true
                        root.menuOpen = modelData
                    }
                }
            }
        }
    }

    HyprBinds {
        id: hyprBinds
    }

    HyprlandFocusGrab {
        id: menuGrab
        windows: root.menuOpen === "System" ? [systemDropdown]
            : root.menuOpen === "Workspace" ? [workspaceDropdown]
            : root.menuOpen === "Window" ? [windowDropdown]
            : root.menuOpen === "View" ? [viewDropdown]
            : root.menuOpen === "Programs" ? [programsDropdown]
            : []
        active: root.systemMenuOpen

        onCleared: {
            root.systemMenuOpen = false
            root.menuOpen = ""
        }
    }

    Dropdown {
        id: systemDropdown
        property var content: ["Terminal", "File Explorer", "Software Center", "Preferences", "br", "Sleep", 
        "Lock Screen", "Log Out", "br", "Shut Down", "Reboot"]
        property var category: "System"
    }

    Dropdown {
        id: workspaceDropdown
        property var content: ["Previous Workspace", "Next Workspace", "New Workspace",
        "br", "Tiled Workspace", "Floating Workspace", "br", "Focused Workspace", "Workspace Overview"]
        property var category: "Workspace"
    }

    Dropdown {
        id: windowDropdown
        property var content: ["Close Window", "Maximize", "Fullscreen", "Minimize", "Pin Window", "br", 
        "Move to Workspace", "Move to New Workspace", "br", "Toggle Floating", "Enable Pseudotiling"]
        property var category: "Window"
    }

    Dropdown {
        id: programsDropdown
        property var content: root.programsContent
        property var category: "Programs"
    }

    Dropdown {
        id: viewDropdown
        property var content: ["Focus Mode", "Toggle Dock", "Automatic Tiling"]
        property var category: "View"
    }
}