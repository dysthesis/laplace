import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var bar
    screen: bar.screen
    anchors.top: true
    anchors.right: true
    margins.top: 42
    margins.right: 16
    implicitWidth: Math.min(380, bar.width - 32)
    implicitHeight: Math.min(stack.implicitHeight, Math.max(1, bar.screen.height - 58))
    exclusionMode: ExclusionMode.Ignore
    color: Theme.background
    visible: bar.primary && Notifications.toasts.length > 0 && Desktop.popover !== "notifications"
    WlrLayershell.namespace: "laplace-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: stack.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: stack
            width: scroll.width
            spacing: 8

            Repeater {
                model: Notifications.toasts

                NotificationCard {
                    required property var modelData
                    entry: modelData
                    compact: true
                    width: stack.width
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            if (y < scroll.contentY)
                                scroll.contentY = y;
                            else if (y + height > scroll.contentY + scroll.height)
                                scroll.contentY = y + height - scroll.height;
                        }
                    }
                }
            }
        }
    }
}
