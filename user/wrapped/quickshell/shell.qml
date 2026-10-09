import Quickshell
import Quickshell.Io

ShellRoot {
    readonly property int notificationCount: Notifications.count

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    IpcHandler {
        target: "desktop"

        function toggleNotifications(): void {
            Desktop.toggleNotifications();
        }

        function toggleQuiet(): void {
            Notifications.toggleQuiet();
        }
    }
}
