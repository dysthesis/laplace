import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

PopupWindow {
    id: root

    property SystemTrayItem trayItem: null
    property var levels: []
    readonly property var page: levels.length ? levels[levels.length - 1] : null
    implicitWidth: 300
    implicitHeight: Math.min(520, Math.max(90, menuContent.implicitHeight + 58))
    color: Theme.popup
    grabFocus: true

    function resetPath() {
        const old = levels;
        levels = [];
        for (const level of old)
            level.destroy();
    }

    function back() {
        if (!levels.length)
            return;
        const old = levels[levels.length - 1];
        levels = levels.slice(0, -1);
        old.destroy();
        scroll.contentY = 0;
        Qt.callLater(root.focusFirst);
    }

    function activate(entry) {
        if (!entry || !entry.enabled)
            return;
        if (entry.hasChildren) {
            const level = levelFactory.createObject(root, { menu: entry, title: entry.text });
            levels = levels.concat([level]);
            scroll.contentY = 0;
            Qt.callLater(root.focusFirst);
        } else {
            entry.triggered();
            visible = false;
        }
    }

    function focusFrom(index, direction) {
        for (let i = index + direction; i >= 0 && i < rows.count; i += direction) {
            const row = rows.itemAt(i);
            if (row && row.control.visible && row.control.enabled) {
                row.control.forceActiveFocus(Qt.TabFocusReason);
                return;
            }
        }
    }

    function focusFirst() {
        focusFrom(-1, 1);
    }

    onTrayItemChanged: {
        resetPath();
        if (!trayItem)
            visible = false;
    }
    onVisibleChanged: {
        if (visible) {
            Desktop.popover = "";
            Qt.callLater(root.focusFirst);
        } else {
            resetPath();
        }
    }

    QsMenuOpener {
        id: topMenu
        menu: root.visible && root.trayItem ? root.trayItem.menu : null
        onChildrenChanged: Qt.callLater(root.focusFirst)
    }

    Component {
        id: levelFactory
        QtObject {
            id: level
            property QsMenuHandle menu: null
            property string title: ""
            property QsMenuOpener opener: QsMenuOpener { menu: level.menu }
            onMenuChanged: {
                if (!menu && root.levels.indexOf(level) >= 0)
                    root.resetPath();
            }
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
        Keys.onLeftPressed: root.back()

        Rectangle {
            anchors.fill: parent
            color: Theme.popup
            border.width: 1
            border.color: Theme.border
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                ShellButton {
                    visible: root.levels.length > 0
                    text: "‹"
                    Accessible.name: "Back to parent menu"
                    onClicked: root.back()
                }
                Text {
                    Layout.fillWidth: true
                    text: root.page ? root.page.title : root.trayItem ? root.trayItem.title || root.trayItem.id : ""
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.muted
                    elide: Text.ElideRight
                }
                ShellButton {
                    text: "×"
                    Accessible.name: "Close tray menu"
                    onClicked: root.visible = false
                }
            }

            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: menuContent.implicitHeight
                contentWidth: width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: menuContent
                    width: scroll.width
                    spacing: 2

                    Repeater {
                        id: rows
                        model: root.page ? root.page.opener.children : topMenu.children

                        Item {
                            required property var modelData
                            required property int index
                            property alias control: button
                            width: menuContent.width
                            height: modelData.isSeparator ? 9 : 28

                            Rectangle {
                                visible: modelData.isSeparator
                                width: parent.width
                                height: 1
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.border
                            }

                            ShellButton {
                                id: button
                                anchors.fill: parent
                                visible: !modelData.isSeparator
                                enabled: modelData.enabled
                                text: (modelData.checkState === Qt.Checked ? "• " : "")
                                    + modelData.text + (modelData.hasChildren ? " ›" : "")
                                onClicked: root.activate(modelData)
                                Keys.onDownPressed: root.focusFrom(index, 1)
                                Keys.onUpPressed: root.focusFrom(index, -1)
                                Keys.onRightPressed: {
                                    if (modelData.hasChildren)
                                        root.activate(modelData);
                                }
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        if (parent.y < scroll.contentY)
                                            scroll.contentY = parent.y;
                                        else if (parent.y + height > scroll.contentY + scroll.height)
                                            scroll.contentY = parent.y + height - scroll.height;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
