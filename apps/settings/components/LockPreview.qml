import QtQuick
import Etude.Ui

// Kleine Vorschau des Sperrbildschirms: Hintergrund, große Uhrzeit, Datum
Rectangle {
    id: root

    property string wallpaper: ""        // Pfad ("" = Farbton)
    property color tint: Theme.muted
    property bool clock24: true

    readonly property int standardWidth: 280
    width: standardWidth
    height: width * 0.5625
    radius: Theme.radiusLg
    color: root.tint
    border.width: 1
    border.color: Theme.border
    clip: true

    property date now: new Date()
    Timer { interval: 30000; running: root.visible; repeat: true; onTriggered: root.now = new Date() }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        sourceSize: Qt.size(480, 270)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, root.clock24 ? "HH:mm" : "h:mm")
            color: "white"
            font.family: Theme.fontSans
            font.pixelSize: Math.round(root.height * 0.24)
            font.weight: Font.DemiBold
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.now.toLocaleDateString(Qt.locale(), "dddd, d. MMMM")
            color: "white"
            font.family: Theme.fontSans
            font.pixelSize: Math.max(9, Math.round(root.height * 0.065))
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
    }

    // Symbole unten rechts (Netzwerk, Akku, Ein/Aus) – nur angedeutet
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 5
        Repeater { model: 3; Rectangle { width: 7; height: 7; radius: 2; color: Qt.rgba(1, 1, 1, 0.8) } }
    }
}
