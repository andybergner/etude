// App-Icon einer Benachrichtigung: Pfad, Icon-Name oder .desktop-Eintrag, sonst Glocke.
import QtQuick
import Quickshell
import Etude.Ui

Item {
    id: root

    property var notif
    property string icon: ""                 // statt notif: Icon-Name/Pfad direkt (Einstellungen)
    property real size: 16
    property color glyphColor: Theme.mutedForeground   // Farbe der Glocke, wenn kein Icon da ist

    width: size
    height: size

    function resolve() {
        let i = icon
        if (i === "" && notif) {
            i = notif.appIcon || ""
            if (i === "" && notif.desktopEntry) {
                const e = DesktopEntries.byId(notif.desktopEntry)
                if (e) i = e.icon
            }
        }
        if (i === "") return ""
        if (i.startsWith("/")) return "file://" + i
        if (i.indexOf("://") > 0) return i
        return Quickshell.iconPath(i, true)
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.resolve()
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }
    Text {
        anchors.centerIn: parent
        visible: !img.visible
        text: String.fromCodePoint(0xF009A)
        color: root.glyphColor
        font.family: Theme.fontIcon
        font.pixelSize: root.size * 0.9
    }
}
