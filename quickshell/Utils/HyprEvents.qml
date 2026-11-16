pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string activeWindowTitle: "Desktop"
    property bool currentlySwitchingWorkspaces: false

    // Jump to a window (and its workspace) as soon as it becomes urgent.
    property bool focusUrgentWindows: true

    // workspace id -> unique window classes in that workspace, e.g. { "1": ["kitty", "codium"] }
    // (the shell's own app windows, class org.quickshell, appear under their title instead)
    property var workspaceApps: ({})
    // workspace id -> true if it has at least one tiled (non-floating) window
    property var workspaceTiled: ({})

    // For the dock
    property var clients: []
    // workspace id -> true if it has a window that makes the dock hide: tiled, maximized or fullscreen
    property var workspaceBlocking: ({})
    // address ("0x...") of the focused window
    property string activeAddress: ""
    readonly property string minimizedWorkspace: "special:minimized"
    function isMinimized(address) {
        for (var i = 0; i < clients.length; i++)
            if (clients[i].address === address) return clients[i].minimized
        return false
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {}
                var tiled = {}
                var blocking = {}
                var list2 = []
                try {
                    var clients = JSON.parse(text)
                    for (var i = 0; i < clients.length; i++) {
                        var c = clients[i]
                        if (!c.mapped || c["class"] === "") continue
                        // every window of the shell's own apps (apps/) has the class org.quickshell, so
                        // those are told apart by title, which matches their desktop entry's Name
                        var app = c["class"] === "org.quickshell" && c.title !== "" ? c.title : c["class"]
                        var minimized = c.workspace.name === root.minimizedWorkspace
                        list2.push({ address: c.address, cls: c["class"], app: app, title: c.title,
                                     workspace: c.workspace.id, minimized: minimized,
                                     w: c.size ? c.size[0] : 0, h: c.size ? c.size[1] : 0 })
                        // special workspaces have no id in the JSON
                        if (minimized || !(c.workspace.id > 0)) continue
                        if (!c.floating || c.fullscreen > 0) blocking[c.workspace.id] = true
                        var list = map[c.workspace.id] || (map[c.workspace.id] = [])
                        if (list.indexOf(app) === -1) list.push(app)
                        if (!c.floating) tiled[c.workspace.id] = true
                    }
                } catch (e) {}
                root.workspaceApps = map
                root.workspaceTiled = tiled
                root.workspaceBlocking = blocking
                root.clients = list2
            }
        }
    }

    function refreshApps() { appsDebounce.restart() }

    Timer {
        id: appsDebounce
        interval: 60
        onTriggered: if (!clientsProc.running) clientsProc.running = true
    }

    Component.onCompleted: refreshApps()

    Timer {
        id: wsTimer
        interval: 1500
        onTriggered: root.currentlySwitchingWorkspaces = false
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activewindowv2")
                root.activeAddress = event.data.trim() === "" ? "" : "0x" + event.data.trim()
            if (event.name === "activewindow") {
                var parts = event.data.split(",")
                var title = parts.slice(1).join(",")
                root.activeWindowTitle = title.length > 0 ? title : "Desktop"
            } else if (event.name === "workspacev2" || event.name === "workspace") {
                root.currentlySwitchingWorkspaces = true
                wsTimer.restart()
                Hyprland.refreshWorkspaces()
            }
            // (a minimized window that turns urgent stays minimized: focusing it would pull its hidden workspace up)
            if (event.name === "urgent" && root.focusUrgentWindows && !root.isMinimized("0x" + event.data.trim())) {
                // data is the window address without the 0x prefix
                Quickshell.execDetached(["hyprctl", "dispatch",
                    "hl.dsp.focus({ window = \"address:0x" + event.data.trim() + "\" })"])
            }
            if (["openwindow", "closewindow", "movewindowv2", "workspacev2", "createworkspacev2",
                 "destroyworkspacev2", "fullscreen", "changefloatingmode"].indexOf(event.name) !== -1)
                root.refreshApps()
            if (event.name === "createworkspacev2" || event.name === "destroyworkspacev2"
                       || event.name === "moveworkspacev2") {
                Hyprland.refreshWorkspaces()
            }
        }
    }
}