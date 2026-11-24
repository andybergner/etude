import QtQuick
import Etude.Ui

// Kachel im Startmenü: Icon oben, Name darunter (eine Zeile, zu lange Namen werden gekürzt,
// damit alle Icons einer Reihe auf gleicher Höhe stehen)
Item {
    id: root

    required property var app          // { id, name, icon }
    property bool selected: false
    property bool keyboardFocus: false       // per Tastatur angesteuert → Fokus-Ring

    signal clicked()
    signal rightClicked(real x, real y)

    implicitHeight: 84

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusMd
        color: "transparent"
        HoverLayer { shown: root.selected || mouse.containsMouse }
        border.width: root.keyboardFocus ? 2 : 0
        border.color: Theme.ring
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(6, (parent.height - implicitHeight) / 2)
        width: parent.width - 12
        spacing: 5

        AppIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.app.icon
            name: root.app.name
            size: 46
            tile: true
        }
        Text {
            width: parent.width
            text: root.app.name
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => e.button === Qt.RightButton ? root.rightClicked(e.x, e.y) : root.clicked()
    }
}
