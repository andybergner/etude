import QtQuick

// shadcn: SidebarGroupLabel – h-8, px-2, text-xs, font-medium, text-sidebar-foreground/70.
// Eingeklappt ausgeblendet (wie im Original: -mt-8 opacity-0).
Item {
    id: root
    property string text: ""
    property bool collapsed: false

    implicitHeight: collapsed ? 0 : 32
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Theme.duration } }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        opacity: root.collapsed ? 0 : 1
        color: Theme.alpha(Theme.sidebarForeground, 0.7)
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}
