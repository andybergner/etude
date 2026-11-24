import QtQuick
import Etude.Ui

// App-Icon aus dem Icon-Theme; fehlt es, ein Kästchen mit dem Anfangsbuchstaben.
// tile: true legt das Icon auf eine Kachel wie bei Apple (abgerundetes Quadrat mit den weichen
// Superellipse-Ecken) – für Taskleiste und Startmenü. Die Icons selbst bleiben ohne Hintergrund.
Item {
    id: root

    property string source: ""
    property string name: ""
    property int size: 32
    property bool tile: false
    readonly property real iconSize: tile ? Math.round(size * 0.72) : size

    // Kachel: heller bzw. dunkler Verlauf passend zum Design, feiner Rand
    readonly property string tileSvg: {
        const top = Theme.dark ? "#3f3f46" : "#ffffff", bottom = Theme.dark ? "#27272a" : "#e4e4e7"
        const edge = Theme.dark ? "#52525c" : "#d4d4d8"
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs>' +
            '<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + top + '"/><stop offset="1" stop-color="' + bottom + '"/></linearGradient></defs>' +
            '<path d="M99.0 50.0 L99.0 66.5 L98.8 71.7 L98.6 75.5 L98.3 78.5 L97.9 81.1 L97.5 83.4 L96.9 85.4 L96.3 87.1 L95.5 88.7 L94.7 90.2 L93.7 91.5 L92.7 92.7 L91.5 93.7 L90.2 94.7 L88.7 95.5 L87.1 96.3 L85.4 96.9 L83.4 97.5 L81.1 97.9 L78.5 98.3 L75.5 98.6 L71.7 98.8 L66.5 99.0 L50.0 99.0 L33.5 99.0 L28.3 98.8 L24.5 98.6 L21.5 98.3 L18.9 97.9 L16.6 97.5 L14.6 96.9 L12.9 96.3 L11.3 95.5 L9.8 94.7 L8.5 93.7 L7.3 92.7 L6.3 91.5 L5.3 90.2 L4.5 88.7 L3.7 87.1 L3.1 85.4 L2.5 83.4 L2.1 81.1 L1.7 78.5 L1.4 75.5 L1.2 71.7 L1.0 66.5 L1.0 50.0 L1.0 33.5 L1.2 28.3 L1.4 24.5 L1.7 21.5 L2.1 18.9 L2.5 16.6 L3.1 14.6 L3.7 12.9 L4.5 11.3 L5.3 9.8 L6.3 8.5 L7.3 7.3 L8.5 6.3 L9.8 5.3 L11.3 4.5 L12.9 3.7 L14.6 3.1 L16.6 2.5 L18.9 2.1 L21.5 1.7 L24.5 1.4 L28.3 1.2 L33.5 1.0 L50.0 1.0 L66.5 1.0 L71.7 1.2 L75.5 1.4 L78.5 1.7 L81.1 2.1 L83.4 2.5 L85.4 3.1 L87.1 3.7 L88.7 4.5 L90.2 5.3 L91.5 6.3 L92.7 7.3 L93.7 8.5 L94.7 9.8 L95.5 11.3 L96.3 12.9 L96.9 14.6 L97.5 16.6 L97.9 18.9 L98.3 21.5 L98.6 24.5 L98.8 28.3 L99.0 33.5 Z" fill="url(#g)" stroke="' + edge + '" stroke-width="1"/></svg>'
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg)
    }
    Image {
        visible: root.tile
        anchors.fill: parent
        source: root.tile ? root.tileSvg : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
    }

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.source
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        asynchronous: true
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        visible: img.status !== Image.Ready && !root.tile
        radius: Theme.radiusSm
        color: Theme.secondary
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: root.name ? root.name.charAt(0).toUpperCase() : "?"
            visible: !root.tile
            color: Theme.secondaryForeground
            font.family: Theme.fontSans
            font.pixelSize: Math.round(root.size * 0.45)
            font.weight: Font.DemiBold
        }
    }
    Text {
        visible: root.tile && img.status !== Image.Ready
        anchors.centerIn: parent
        text: root.name ? root.name.charAt(0).toUpperCase() : "?"
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: Math.round(root.size * 0.42)
        font.weight: Font.DemiBold
    }
}
