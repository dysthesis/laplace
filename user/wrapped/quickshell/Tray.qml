import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Row {
    id: root

    required property var bar
    spacing: 2

    function openMenu(item, button) {
        if (!item.hasMenu)
            return;
        menu.visible = false;
        menu.trayItem = item;
        menu.anchor.item = button;
        menu.visible = true;
    }

    TrayMenu {
        id: menu
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 8
    }

    Repeater {
        model: SystemTray.items

        ShellButton {
            id: button
            required property var modelData
            text: modelData.title || modelData.id
            width: Math.min(84, implicitWidth)
            visible: modelData.status !== Status.Passive
            marked: modelData.status === Status.NeedsAttention
            markColor: Theme.warning
            helpText: modelData.tooltipTitle || modelData.title || modelData.id
            Accessible.name: text
            Accessible.description: "Activate tray item; Menu or right-click opens its menu"
            onClicked: {
                if (modelData.onlyMenu)
                    root.openMenu(modelData, button);
                else
                    modelData.activate();
            }
            onContextRequested: root.openMenu(modelData, button)
            onSecondaryClicked: modelData.secondaryActivate()
            onScrolled: (delta, horizontal) => modelData.scroll(delta, horizontal)
        }
    }
}
