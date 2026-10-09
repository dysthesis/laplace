pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool connected: false
    property var workspaces: []
    property var windows: ({})
    property int revision: 0
    property var pendingWorkspace: null

    function forOutput(output) {
        const changed = revision;
        return workspaces.filter(workspace => workspace.output === output)
            .sort((a, b) => a.idx - b.idx);
    }

    function titleForOutput(output) {
        const changed = revision;
        const workspace = workspaces.find(workspace => workspace.output === output && workspace.is_active);
        if (!workspace)
            return "";
        const window = windows[workspace.active_window_id];
        return window ? (window.title || window.app_id || "") : "";
    }

    function reset() {
        connected = false;
        workspaces = [];
        windows = ({});
        pendingWorkspace = null;
        revision++;
        actionSocket.connected = false;
    }

    function receive(line) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (_) {
            return;
        }

        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces;
            connected = true;
        } else if (event.WorkspaceActivated) {
            const data = event.WorkspaceActivated;
            const active = workspaces.find(workspace => workspace.id === data.id);
            if (!active)
                return;
            for (const workspace of workspaces) {
                if (workspace.output === active.output)
                    workspace.is_active = workspace.id === data.id;
                if (data.focused)
                    workspace.is_focused = workspace.id === data.id;
            }
        } else if (event.WorkspaceActiveWindowChanged) {
            const data = event.WorkspaceActiveWindowChanged;
            const workspace = workspaces.find(workspace => workspace.id === data.workspace_id);
            if (workspace)
                workspace.active_window_id = data.active_window_id;
        } else if (event.WorkspaceUrgencyChanged) {
            const data = event.WorkspaceUrgencyChanged;
            const workspace = workspaces.find(workspace => workspace.id === data.id);
            if (workspace)
                workspace.is_urgent = data.urgent;
        } else if (event.WindowsChanged) {
            const next = ({});
            for (const window of event.WindowsChanged.windows)
                next[window.id] = window;
            windows = next;
        } else if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window;
            if (window.is_focused) {
                for (const id in windows)
                    windows[id].is_focused = false;
            }
            windows[window.id] = window;
        } else if (event.WindowClosed) {
            delete windows[event.WindowClosed.id];
        } else if (event.WindowFocusChanged) {
            const focused = event.WindowFocusChanged.id;
            for (const id in windows)
                windows[id].is_focused = windows[id].id === focused;
        } else {
            return;
        }
        revision++;
    }

    function sendFocus(id) {
        actionSocket.write(JSON.stringify({
            Action: { FocusWorkspace: { reference: { Id: id } } }
        }) + "\n");
        actionSocket.flush();
    }

    function focusWorkspace(id) {
        if (!connected || !workspaces.some(workspace => workspace.id === id))
            return;
        if (actionSocket.connected) {
            sendFocus(id);
        } else {
            pendingWorkspace = id;
            actionSocket.connected = true;
        }
    }

    Socket {
        id: actionSocket
        path: Quickshell.env("NIRI_SOCKET") || ""
        parser: SplitParser {}
        onConnectionStateChanged: {
            if (connected && root.pendingWorkspace !== null) {
                root.sendFocus(root.pendingWorkspace);
                root.pendingWorkspace = null;
            }
        }
        onError: root.pendingWorkspace = null
    }

    Process {
        id: events
        command: [Theme.niri, "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => root.receive(data)
        }
        onRunningChanged: {
            if (!running) {
                root.reset();
                reconnect.restart();
            }
        }
    }

    Timer {
        id: reconnect
        interval: 2000
        onTriggered: events.running = true
    }
}
