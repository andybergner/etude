import QtQuick

// shadcn: SidebarMenuButton – h-8, px-2, gap-2, text-sm, rounded-md,
// hover/aktiv: bg-sidebar-accent, aktiv zusätzlich font-medium.
// Eingeklappt (collapsed): nur das Icon, 32×32.
//   SidebarMenuButton { icon: "…"; text: "System"; active: true }
Item {
    id: root

    property string icon: ""
    property string text: ""
    property bool active: false
    property bool collapsed: false
    property string size: "default"      // "default" (h-8) | "lg" (h-12)

    signal clicked()

    // Wie die Navigationsleiste bei Windows: in einem Bereich (arrowScope) ist nur der aktive Eintrag
    // eine Tab-Station, die anderen erreicht man mit den Pfeilen; Tab verlässt die Leiste.
    readonly property bool navigable: true
    activeFocusOnTab: active || activeFocus || FocusNav.rovingFirst(root)
    implicitHeight: size === "lg" ? 48 : 32
    implicitWidth: collapsed ? implicitHeight : 200

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: "transparent"
        HoverLayer { color: Theme.sidebarAccent; shown: root.active || mouse.containsMouse }
    }

    // Fokus-Ring (Tastatur)
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: "transparent"
        border.width: 2
        border.color: Theme.sidebarRing
        visible: root.activeFocus
    }

    // Icon: eingeklappt exakt mittig im Button (Glyphen der Nerd Font sind
    // unterschiedlich breit – darum zentriert statt linksbündig in fester Breite)
    Text {
        id: ico
        width: 20
        x: root.collapsed ? (root.width - width) / 2 : 6
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: root.icon
        color: root.active ? Theme.sidebarAccentForeground : Theme.sidebarForeground
        font.family: Theme.fontIcon
        font.pixelSize: 16
    }
    Text {
        visible: !root.collapsed && root.text !== ""
        anchors.left: ico.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: Text.ElideRight
        color: root.active ? Theme.sidebarAccentForeground : Theme.sidebarForeground
        font.family: Theme.fontSans
        font.pixelSize: 14
        font.weight: root.active ? Font.Medium : Font.Normal
    }


    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Keys.onPressed: (e) => FocusNav.key(root, e)        // Pfeiltasten: zum Nachbarn
    readonly property bool ownFocusRing: true           // FocusRoot zeichnet keinen zusätzlichen Ring
}
