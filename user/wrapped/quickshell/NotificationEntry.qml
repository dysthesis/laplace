import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    required property var service
    property Notification live: null
    property string appName: ""
    property string summary: ""
    property string body: ""
    property var actions: []
    property date receivedAt
    property bool critical: false
    property bool ephemeral: false
    property bool toastVisible: false
    property int pauseCount: 0
    property real remaining: 0
    property real deadline: 0

    function update(replaced) {
        if (!live)
            return;
        appName = live.appName || live.desktopEntry || "Notification";
        summary = live.summary;
        body = live.body;
        actions = live.actions.map(action => ({ identifier: action.identifier, text: action.text }));
        receivedAt = new Date();
        critical = live.urgency === NotificationUrgency.Critical;
        ephemeral = live.transient;
        toastVisible = (replaced || !live.lastGeneration) && (!service.quiet || critical);
        expiry.stop();
        // Quickshell 0.3 exposes raw milliseconds despite its seconds documentation.
        remaining = critical || live.expireTimeout === 0 ? 0
            : live.expireTimeout > 0 ? live.expireTimeout : 6500;
        resumeTimer();
        if (replaced)
            service.promote(root);
        else
            service.publish();
    }

    function scheduleUpdate() {
        expiry.stop();
        Qt.callLater(root.update, true);
    }

    function resumeTimer() {
        if (live && remaining > 0 && pauseCount === 0) {
            expiry.interval = Math.max(1, remaining);
            deadline = Date.now() + remaining;
            expiry.start();
        }
    }

    function pause() {
        if (pauseCount === 0 && expiry.running) {
            remaining = Math.max(1, deadline - Date.now());
            expiry.stop();
        }
        pauseCount++;
    }

    function resume() {
        pauseCount = Math.max(0, pauseCount - 1);
        if (pauseCount === 0)
            resumeTimer();
    }

    function dismiss() {
        if (live)
            live.dismiss();
        else
            service.remove(root);
    }

    function invoke(identifier) {
        if (!live || !live.tracked)
            return;
        const action = live.actions.find(action => action.identifier === identifier);
        if (action)
            action.invoke();
    }

    property Timer expiry: Timer {
        onTriggered: {
            if (root.live)
                root.live.expire();
        }
    }

    property Connections events: Connections {
        target: root.live

        function onClosed(reason) {
            root.expiry.stop();
            root.live = null;
            root.actions = [];
            root.toastVisible = false;
            root.service.closed(root, reason);
        }

        function onSummaryChanged() { root.scheduleUpdate(); }
        function onBodyChanged() { root.scheduleUpdate(); }
        function onAppNameChanged() { root.scheduleUpdate(); }
        function onAppIconChanged() { root.scheduleUpdate(); }
        function onDesktopEntryChanged() { root.scheduleUpdate(); }
        function onImageChanged() { root.scheduleUpdate(); }
        function onUrgencyChanged() { root.scheduleUpdate(); }
        function onExpireTimeoutChanged() { root.scheduleUpdate(); }
        function onActionsChanged() {
            root.actions = root.live.actions.map(action => ({
                identifier: action.identifier, text: action.text
            }));
            root.scheduleUpdate();
        }
        function onResidentChanged() { root.scheduleUpdate(); }
        function onTransientChanged() { root.scheduleUpdate(); }
        function onHintsChanged() { root.scheduleUpdate(); }
        function onHasActionIconsChanged() { root.scheduleUpdate(); }
    }
}
