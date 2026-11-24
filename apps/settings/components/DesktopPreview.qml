import QtQuick
import Etude.Ui

// Kleine Vorschau des Desktops: Hintergrund, Taskleiste (oben/unten), Fenster in Akzentfarbe
Rectangle {
    id: root

    property string wallpaper: ""        // Pfad ("" = Farbton)
    property color tint: Theme.muted
    property bool barTop: false

    // überall gleich groß: 280 × 158 (16:9), bei wenig Platz schmaler
    readonly property int standardWidth: 280
    width: standardWidth                 // Seiten setzen: Math.min(standardWidth, root.width)
    height: width * 0.5625
    radius: Theme.radiusLg
    color: root.tint
    border.width: 1
    border.color: Theme.border
    clip: true

    Image {
        anchors.fill: parent
        anchors.margins: 1
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        sourceSize: Qt.size(480, 270)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Fenster
    Rectangle {
        x: parent.width * 0.18; y: parent.height * (root.barTop ? 0.28 : 0.18)
        width: parent.width * 0.5; height: parent.height * 0.5
        radius: 5
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        Rectangle {
            x: 8; y: 8; width: parent.width * 0.4; height: 6; radius: 3
            color: Theme.primary
        }
        Column {
            x: 8; y: 22; spacing: 5
            Repeater { model: 3; Rectangle { width: 60 - index * 12; height: 4; radius: 2; color: Theme.muted } }
        }
    }

    // Taskleiste
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 1; anchors.rightMargin: 1
        y: root.barTop ? 1 : parent.height - height - 1
        height: 14
        color: Theme.sidebar
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 6; spacing: 4
            Rectangle { width: 7; height: 7; radius: 2; color: Theme.primary }
            Repeater { model: 4; Rectangle { width: 4; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.mutedForeground } }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 4; radius: 2; color: Theme.mutedForeground
        }
    }
}
