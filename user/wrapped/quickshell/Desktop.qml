pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property var primaryScreen: {
        const screens = Quickshell.screens;
        return screens.find(screen => screen.name === Theme.primaryOutput) || screens[0] || null;
    }
    property string popover: ""

    onPrimaryScreenChanged: popover = ""

    function toggleNotifications() {
        popover = popover === "notifications" ? "" : "notifications";
    }

    function toggleDate() {
        popover = popover === "date" ? "" : "date";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date date: clock.date
}
