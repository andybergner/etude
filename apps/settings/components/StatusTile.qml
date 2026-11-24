import QtQuick
import Etude.Ui

// Kleiner Status oben auf der System-Seite: Icon, Titel, Zeile darunter
Row {
    id: root
    property string icon: ""
    property string label: ""
    property string desc: ""
    spacing: 10

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.primary
        font.family: Theme.fontIcon
        font.pixelSize: 20
    }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontSans
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            text: root.desc
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }
}
