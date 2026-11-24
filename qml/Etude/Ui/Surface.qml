import QtQuick

// Fläche für Menüs und Popover (shadcn: Popover/DropdownMenuContent):
// bg-popover, 1px border, rounded-md, shadow-md
Item {
    id: root

    default property alias content: inner.data
    property real radius: Theme.radiusMd
    property real padding: 4                 // shadcn: p-1

    // weicher Schatten (ohne GPU-Effekte, funktioniert überall)
    Repeater {
        model: 4
        Rectangle {
            required property int index
            anchors.fill: parent
            anchors.margins: -(index + 1)
            anchors.topMargin: -(index + 1) + 2
            radius: root.radius + index + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, Theme.dark ? 0.18 - index * 0.04 : 0.07 - index * 0.015)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.alpha(Theme.popover, Theme.glassPopover)
        border.width: 1
        border.color: Theme.border
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
