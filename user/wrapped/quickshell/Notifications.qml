pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool quiet: false
    property var entries: []
    property var inbox: []
    property var toasts: []
    readonly property int count: inbox.length
    readonly property int retentionLimit: 40

    function toggleQuiet() {
        quiet = !quiet;
    }

    onQuietChanged: {
        if (quiet) {
            for (const entry of entries) {
                if (!entry.critical)
                    entry.toastVisible = false;
            }
        }
        publish();
    }

    function publish() {
        inbox = entries.filter(entry => !entry.ephemeral);
        const visible = entries.filter(entry => entry.live && entry.toastVisible);
        visible.sort((a, b) => Number(b.critical) - Number(a.critical));
        for (let i = 3; i < visible.length; i++)
            visible[i].toastVisible = false;
        toasts = visible.slice(0, 3);
    }

    function receive(notification) {
        notification.tracked = true;
        while (entries.length >= retentionLimit)
            entries[entries.length - 1].dismiss();
        const entry = entryFactory.createObject(root, { service: root, live: notification });
        entries.unshift(entry);
        entry.update(false);
    }

    function promote(entry) {
        const index = entries.indexOf(entry);
        if (index < 0)
            return;
        entries.splice(index, 1);
        entries.unshift(entry);
        publish();
    }

    function closed(entry, reason) {
        if (reason === NotificationCloseReason.Expired && !entry.ephemeral)
            publish();
        else
            remove(entry);
    }

    function remove(entry) {
        const index = entries.indexOf(entry);
        if (index < 0)
            return;
        entries.splice(index, 1);
        publish();
        entry.destroy();
    }

    function clear() {
        const retained = inbox.slice();
        for (const entry of retained)
            entry.dismiss();
    }

    Component {
        id: entryFactory
        NotificationEntry {}
    }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: false
        actionIconsSupported: false
        inlineReplySupported: false
        onNotification: notification => root.receive(notification)
    }
}
