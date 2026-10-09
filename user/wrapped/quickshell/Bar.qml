import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    readonly property bool primary: screen === Desktop.primaryScreen
    screen: modelData
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 34
    exclusiveZone: 34
    color: Theme.surface
    WlrLayershell.namespace: "laplace-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        Keys.onEscapePressed: Desktop.popover = ""

        ShellButton {
            text: "Apps"
            helpText: "Vicinae · apps, clipboard and calculator"
            onClicked: {
                Desktop.popover = "";
                Quickshell.execDetached([Theme.vicinae, "toggle"]);
            }
        }

        Flickable {
            id: workspaceViewport
            Layout.preferredWidth: Math.min(workspaces.implicitWidth, root.width * 0.35)
            Layout.preferredHeight: 28
            contentWidth: workspaces.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Workspaces {
                id: workspaces
                output: root.screen.name
                onReveal: (position, size) => {
                    if (position < workspaceViewport.contentX)
                        workspaceViewport.contentX = position;
                    else if (position + size > workspaceViewport.contentX + workspaceViewport.width)
                        workspaceViewport.contentX = position + size - workspaceViewport.width;
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.maximumWidth: 420
            text: Niri.connected ? Niri.titleForOutput(root.screen.name) : "Niri unavailable"
            textFormat: Text.PlainText
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Item { Layout.fillWidth: true }

        Row {
            visible: root.primary
            spacing: 4

            Audio {}
            Tray { bar: root }

            ShellButton {
                text: Qt.formatDateTime(Desktop.date, "HH:mm")
                numeric: true
                marked: Desktop.popover === "date"
                helpText: Qt.formatDateTime(Desktop.date, "dddd, d MMMM yyyy · HH:mm t")
                Accessible.name: helpText
                onClicked: Desktop.toggleDate()
            }

            ShellButton {
                text: "Inbox " + Notifications.count
                marked: Desktop.popover === "notifications"
                helpText: "Notification inbox · " + Notifications.count + " retained"
                onClicked: Desktop.toggleNotifications()
                contentItem: Row {
                    spacing: 5
                    Text {
                        text: "Inbox"
                        textFormat: Text.PlainText
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                    Text {
                        text: Notifications.count
                        textFormat: Text.PlainText
                        color: Theme.muted
                        font.family: Theme.monoFamily
                        font.pixelSize: 13
                    }
                }
            }

            ShellButton {
                text: "Quiet"
                marked: Notifications.quiet
                markColor: Theme.warning
                helpText: Notifications.quiet ? "Quiet mode on · critical alerts still appear" : "Quiet mode off"
                Accessible.checkable: true
                Accessible.checked: Notifications.quiet
                onClicked: Notifications.toggleQuiet()
            }

            ShellButton {
                text: "Lock"
                helpText: "Lock the session"
                onClicked: {
                    Desktop.popover = "";
                    Quickshell.execDetached([Theme.locker]);
                }
            }
        }
    }

    NotificationInbox { bar: root }
    DatePopover { bar: root }
    NotificationToasts { bar: root }
}
