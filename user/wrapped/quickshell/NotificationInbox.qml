import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var bar
    screen: bar.screen
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "laplace-inbox"
    WlrLayershell.layer: WlrLayer.Overlay
    // IPC opens have no pointer serial for an xdg_popup grab.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: bar.primary && Desktop.popover === "notifications"

    onVisibleChanged: {
        if (visible)
            quietButton.forceActiveFocus(Qt.PopupFocusReason);
        else if (bar.primary && Desktop.popover === "notifications")
            Desktop.popover = "";
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Desktop.popover = ""
    }

    FocusScope {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 42
        anchors.rightMargin: 16
        width: Math.min(420, parent.width - 32)
        height: Math.min(600, parent.height - 70, Math.max(180, cards.implicitHeight + (Notifications.quiet ? 100 : 70)))
        focus: true
        Keys.onEscapePressed: Desktop.popover = ""

        Rectangle {
            anchors.fill: parent
            color: Theme.popup
            border.color: Theme.border
            border.width: 1
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Notifications · " + Notifications.count
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                ShellButton {
                    id: quietButton
                    text: Notifications.quiet ? "Quiet" : "Live"
                    marked: Notifications.quiet
                    markColor: Theme.warning
                    helpText: "Quiet mode silences non-critical toasts"
                    onClicked: Notifications.toggleQuiet()
                }

                ShellButton {
                    id: clearButton
                    text: "Clear"
                    enabled: Notifications.count > 0
                    onClicked: Notifications.clear()
                }

                ShellButton {
                    text: "×"
                    Accessible.name: "Close notification inbox"
                    onClicked: Desktop.popover = ""
                }
            }

            Text {
                visible: Notifications.quiet
                Layout.fillWidth: true
                text: "Quiet mode · critical alerts still appear"
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: cards.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: cards
                    width: scroll.width - (scrollbar.visible ? 10 : 0)
                    spacing: 8

                    Repeater {
                        model: Notifications.inbox

                        NotificationCard {
                            required property var modelData
                            entry: modelData
                            width: cards.width
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    if (y < scroll.contentY)
                                        scroll.contentY = y;
                                    else if (y + height > scroll.contentY + scroll.height)
                                        scroll.contentY = Math.min(y, y + height - scroll.height);
                                }
                            }
                        }
                    }

                    Text {
                        visible: Notifications.count === 0
                        width: cards.width
                        height: 100
                        text: "All caught up"
                        textFormat: Text.PlainText
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    id: scrollbar
                    policy: ScrollBar.AsNeeded
                    visible: scroll.contentHeight > scroll.height
                    width: 5
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 2
                        color: Theme.dim
                    }
                    background: Rectangle { color: Theme.popup }
                }
            }
        }
    }
}
