import QtQuick
import QtQuick.Effects

// Benutzerbild (shadcn: Avatar): rund (oder mit eigenem radius), Initiale auf bg-muted,
// optional ein Bild – das Bild wird passend zur Form ausgeschnitten.
Rectangle {
    id: root
    property string name: ""
    property url source: ""
    property real size: 32

    width: size; height: size
    radius: size / 2
    color: Theme.muted

    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: root.name.length > 0 ? root.name[0].toUpperCase() : "?"
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: root.size * 0.42
        font.weight: Font.Medium
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    // Bild in die Form (Kreis bzw. abgerundetes Quadrat) schneiden
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        maskEnabled: true
        maskSource: mask
    }
    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: root.radius }
    }
}
