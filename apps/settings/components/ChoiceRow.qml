import QtQuick
import Etude.Ui

// Zeile innerhalb eines Expanders: Auswahlkreis, Icon, Name (ganze Zeile klickbar)
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string desc: ""
    property bool checked: false
    signal clicked()

    implicitHeight: desc ? 56 : 48
    HoverLayer { radius: 0; shown: mouse.containsMouse }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 56                 // eingerückt unter den Titel des Expanders
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14
        Radio { anchors.verticalCenter: parent.verticalCenter; checked: root.checked }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: Theme.mutedForeground
            font.family: Theme.fontIcon
            font.pixelSize: 16
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 13
            }
            Text {
                visible: root.desc !== ""
                text: root.desc
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 12
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
