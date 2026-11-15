import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Theme"

// Opened from anywhere through IPC: qs ipc call search toggle | open | close
// Hyprland binds it in ~/.config/hypr/modules/input.lua. The window only exists while it's open.

Scope {
    id: root
    property bool shown: false

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win
            // covers the screen so a click anywhere outside the card closes the search
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            // own namespace so Hyprland can blur the card but not its drop shadow
            // (layer rule in ~/.config/hypr/modules/windowrules.lua)
            WlrLayershell.namespace: "quickshell-search"
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: root.shown = false
            }

            SearchContent {
                anchors.fill: parent
                onCloseRequested: root.shown = false
            }
        }
    }

    IpcHandler {
        target: "search"
        function toggle(): void { root.shown = !root.shown }
        function open(): void { root.shown = true }
        function close(): void { root.shown = false }
    }
}
