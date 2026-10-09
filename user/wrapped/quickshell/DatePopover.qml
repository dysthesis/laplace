import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root

    required property var bar
    anchor.window: bar
    anchor.rect.x: Math.max(16, bar.width - implicitWidth - 16)
    anchor.rect.y: bar.height + 8
    implicitWidth: Math.min(300, bar.width - 32)
    implicitHeight: 132
    color: Theme.popup
    grabFocus: true
    visible: bar.primary && Desktop.popover === "date"

    onVisibleChanged: {
        if (visible)
            closeButton.forceActiveFocus(Qt.PopupFocusReason);
        else if (bar.primary && Desktop.popover === "date")
            Desktop.popover = "";
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Desktop.popover = ""

        Rectangle {
            anchors.fill: parent
            color: Theme.popup
            border.color: Theme.border
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(Desktop.date, "dddd")
                    textFormat: Text.PlainText
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
                ShellButton {
                    id: closeButton
                    text: "×"
                    Accessible.name: "Close date popover"
                    onClicked: Desktop.popover = ""
                }
            }

            Text {
                text: Qt.formatDateTime(Desktop.date, "d MMMM yyyy")
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 17
            }

            Text {
                text: Qt.formatDateTime(Desktop.date, "HH:mm t")
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 13
            }
        }
    }
}
