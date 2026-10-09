import QtQuick
import QtQuick.Controls

import Quickshell
Button {
    id: root

    property bool numeric: false
    property bool marked: false
    property color markColor: Theme.focus
    property color textColor: Theme.foreground
    property string helpText: ""
    signal contextRequested()
    signal secondaryClicked()
    signal scrolled(real delta, bool horizontal)

    implicitHeight: 28
    implicitWidth: Math.max(28, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: 8
    rightPadding: 8
    topPadding: 3
    bottomPadding: 3
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: numeric ? Theme.monoFamily : Theme.fontFamily
    font.pixelSize: 13
    Accessible.name: text

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onMenuPressed: contextRequested()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
            contextRequested();
            event.accepted = true;
        }
    }

    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        font: root.font
        color: root.enabled ? root.textColor : Theme.dim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 3
        color: root.down ? Theme.inset : root.hovered ? Theme.popup : Theme.surface
        border.width: root.visualFocus ? 1 : 0
        border.color: Theme.focus

        Rectangle {
            visible: root.marked
            width: 8
            height: 2
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.markColor
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            if (mouse.button === Qt.RightButton)
                root.contextRequested();
            else
                root.secondaryClicked();
        }
        onWheel: wheel => {
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
            root.scrolled(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
            wheel.accepted = true;
        }
    }

    Timer {
        id: tooltipDelay
        interval: 650
        running: root.hovered && root.helpText.length > 0
        onTriggered: tooltip.visible = true
    }

    onHoveredChanged: {
        if (!hovered)
            tooltip.visible = false;
    }

    PopupWindow {
        id: tooltip
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        implicitWidth: Math.min(360, tooltipText.implicitWidth + 16)
        implicitHeight: tooltipText.implicitHeight + 16
        color: Theme.popup

        Rectangle {
            anchors.fill: parent
            color: Theme.popup
            border.color: Theme.border
        }

        Text {
            id: tooltipText
            anchors.fill: parent
            anchors.margins: 8
            text: root.helpText
            textFormat: Text.PlainText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.foreground
            wrapMode: Text.Wrap
        }
    }
}
