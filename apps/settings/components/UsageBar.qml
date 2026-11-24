import QtQuick
import Etude.Ui

// Belegungsbalken (shadcn Progress): Anteil 0..1, ab 90 % rot
Rectangle {
    id: root
    property real value: 0
    property color fill: value >= 0.9 ? Theme.destructive : Theme.primary

    implicitHeight: 8
    radius: height / 2
    color: Theme.alpha(Theme.primary, 0.15)

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.min(1, Math.max(0, root.value)))
        height: parent.height
        radius: parent.radius
        color: root.fill
        visible: root.value > 0
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }
}
