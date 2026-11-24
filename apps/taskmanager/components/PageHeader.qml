import QtQuick
import Etude.Ui

// Kopf einer Task-Manager-Seite: Titel links, Aktionen rechts (wie Windows 11).
//   PageHeader { title: "Prozesse"; Button { … } Button { … } }
Item {
    id: root

    property string title: ""
    default property alias actions: actionRow.data

    implicitHeight: 56

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
