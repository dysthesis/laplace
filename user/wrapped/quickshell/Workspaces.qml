import QtQuick

Row {
    id: root

    required property string output
    spacing: 2
    signal reveal(real position, real size)

    Repeater {
        id: buttons
        model: Niri.forOutput(root.output)

        ShellButton {
            required property var modelData
            required property int index
            text: modelData.name || String(modelData.idx)
            numeric: !modelData.name
            textColor: modelData.is_active ? Theme.foreground : Theme.muted
            width: Math.min(96, implicitWidth)
            marked: modelData.is_active
            markColor: modelData.is_focused ? Theme.focus : Theme.muted
            helpText: "Workspace " + text + (modelData.is_urgent ? " · needs attention" : "")
            onClicked: Niri.focusWorkspace(modelData.id)
            onActiveFocusChanged: {
                if (activeFocus)
                    root.reveal(x, width);
            }
            Keys.onLeftPressed: {
                const button = buttons.itemAt(Math.max(0, index - 1));
                if (button)
                    button.forceActiveFocus(Qt.TabFocusReason);
            }
            Keys.onRightPressed: {
                const button = buttons.itemAt(Math.min(buttons.count - 1, index + 1));
                if (button)
                    button.forceActiveFocus(Qt.TabFocusReason);
            }

            Rectangle {
                visible: modelData.is_urgent
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 3
                width: 3
                height: 3
                radius: 2
                color: Theme.urgent
            }
        }
    }
}
