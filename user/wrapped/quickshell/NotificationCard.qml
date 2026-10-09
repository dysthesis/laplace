import QtQuick
import QtQuick.Layouts

FocusScope {
    id: root

    required property var entry
    property bool compact: false
    property bool paused: false
    readonly property bool interacting: hover.hovered || activeFocus
    implicitHeight: content.implicitHeight + 24

    onInteractingChanged: {
        if (entry && interacting && !paused) {
            entry.pause();
            paused = true;
        } else if (entry && !interacting && paused) {
            entry.resume();
            paused = false;
        }
    }
    Component.onDestruction: {
        if (entry && paused)
            entry.resume();
    }

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        color: Theme.popup
        radius: 4
        border.width: 1
        border.color: Theme.border
    }

    Rectangle {
        visible: root.entry.critical
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: 2
        color: Theme.urgent
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.entry.appName
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                text: Qt.formatDateTime(root.entry.receivedAt, "HH:mm")
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 11
            }

            ShellButton {
                text: "×"
                implicitWidth: 24
                implicitHeight: 24
                helpText: "Dismiss notification"
                Accessible.name: "Dismiss notification from " + root.entry.appName
                onClicked: root.entry.dismiss()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.entry.summary
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 2 : 2147483647
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.entry.body
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 4 : 2147483647
            elide: Text.ElideRight
        }

        Flow {
            Layout.fillWidth: true
            visible: root.entry.actions.length > 0
            spacing: 6

            Repeater {
                model: root.entry.actions

                ShellButton {
                    required property var modelData
                    text: modelData.text || (modelData.identifier === "default" ? "Open" : modelData.identifier)
                    width: Math.min(implicitWidth, content.width)
                    enabled: root.entry.live !== null
                    onClicked: root.entry.invoke(modelData.identifier)
                }
            }
        }
    }
}
