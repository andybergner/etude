import QtQuick
import Etude.Ui

// Taskleisten-Button im Windows-11-Stil, Farben aus dem Theme (shadcn sidebar-*):
// Hover = sidebar-accent, Klick etwas schwächer, feiner Rand in sidebar-border.
Item {
    id: root

    default property alias content: row.data
    property alias overlay: overlayItem.data     // frei platziert über dem Button (z. B. Zähler an der Ecke)
    property real padX: 10
    property real spacing: 8
    property bool forceHover: false      // nur für Vorschauen

    readonly property bool hovered: mouse.containsMouse || forceHover

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int direction)

    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: "transparent"
        border.width: root.hovered ? 1 : 0
        border.color: Theme.sidebarBorder
        HoverLayer {
            color: Theme.sidebarAccent
            shown: root.hovered || mouse.pressed
            level: mouse.pressed ? 0.6 : 1
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }

    Item { id: overlayItem; anchors.fill: parent; z: 5 }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (e) => e.button === Qt.RightButton ? root.rightClicked()
                        : e.button === Qt.MiddleButton ? root.middleClicked() : root.clicked()
        onWheel: (e) => root.scrolled(e.angleDelta.y > 0 ? 1 : -1)
    }
}
