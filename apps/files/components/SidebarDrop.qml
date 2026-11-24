import QtQuick
import Etude.Ui
import "DropUtil.js" as DropUtil

// Ablagefläche über einem Sidebar-Eintrag (Ordner, Laufwerk, Papierkorb):
// hebt den Eintrag beim Darüberziehen hervor und meldet die abgelegten Pfade.
Item {
    id: root

    property string target: ""
    signal dropped(var paths, bool copy)

    anchors.fill: parent

    DropArea {
        id: area
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]
        onDropped: (drop) => {
            const p = DropUtil.paths(drop).filter(x => x !== root.target)
            if (!p.length) return
            drop.acceptProposedAction()
            root.dropped(p, DropUtil.isCopy(drop))
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: area.containsDrag
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.primary, 0.18)
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.8)
    }
}
