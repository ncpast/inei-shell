pragma ComponentBehavior: Bound
import Quickshell
import QtQuick.Layouts
import Quickshell.Io
import QtQuick
import "../../Theme"

// The shell's settings app: a normal (floating) window, opened from anywhere through IPC:
//   qs ipc call settings toggle | open | close
// SUPER + comma (hypr/modules/input.lua) and the "Shell Settings" desktop entry
// (~/.local/share/applications/quickshell-settings.desktop, so rofi lists it) both use it.
//
// The window only exists while it's open: a LazyLoader creates a fresh one on open and destroys it
// on close. Closing it like any other window (SUPER + C, the title bar) destroys the native window
// behind Quickshell's back, so `closed` resets the state; reusing that window wouldn't come back.
Scope {
    id: root
    property bool shown: false

    LazyLoader {
        active: root.shown

        FloatingWindow {
            visible: true
            title: "Shell Settings"
            implicitWidth: 900
            implicitHeight: 600
            onClosed: root.shown = false
            color: "transparent"

            // placeholder until the real settings UI exists
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillHeight: true
                    width: parent.width * 0.2
                    color: Theme.background
                    opacity: 0.9
                }


                Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    color: Theme.background
                }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.shown = !root.shown }
        function open(): void { root.shown = true }
        function close(): void { root.shown = false }
    }
}
