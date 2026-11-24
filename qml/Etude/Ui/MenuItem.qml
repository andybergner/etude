import QtQuick
import QtQuick.Layouts

// Menüeintrag (shadcn: DropdownMenuItem / DropdownMenuSubTrigger)
//   MenuItem { icon: "…"; text: "Terminal"; shortcut: "Super Enter" }
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string shortcut: ""
    property string variant: "default"       // "default" | "destructive"
    property bool hasSubmenu: false
    property bool highlighted: false         // Hover oder Tastatur
    property bool disabled: false
    property bool checkable: false           // Auswahlliste (z. B. Ansicht, Sortieren): Haken rechts
    property bool checked: false

    signal clicked()
    signal hoveredChanged2(bool hovered)

    readonly property bool destructive: variant === "destructive"
    readonly property color textColor: destructive ? Theme.destructive
                                     : highlighted ? Theme.accentForeground
                                     : Theme.popoverForeground
    readonly property color iconColor: destructive ? Theme.destructive
                                     : highlighted ? Theme.accentForeground
                                     : Theme.mutedForeground

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 16
    opacity: disabled ? 0.5 : 1

    // Hintergrund beim Hervorheben: bg-accent bzw. destructive/10
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: !root.highlighted || root.disabled ? "transparent"
             : root.destructive ? Theme.alpha(Theme.destructive, Theme.dark ? 0.2 : 0.1)
             : Theme.accent
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            font.family: Theme.fontIcon
            font.pixelSize: 16
            Layout.preferredWidth: 16
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: root.text
            color: root.textColor
            font.family: Theme.fontSans
            font.pixelSize: 14
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        // shadcn: DropdownMenuShortcut (ml-auto text-xs tracking-widest text-muted-foreground)
        Text {
            visible: root.shortcut !== "" && !root.hasSubmenu
            text: root.shortcut
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.letterSpacing: 1
        }
        // Haken rechts – der Platz bleibt auch ohne Haken frei, damit alle Texte gleich stehen
        Text {
            visible: root.checkable
            text: root.checked ? String.fromCodePoint(0xF012C) : ""
            color: root.iconColor
            font.family: Theme.fontIcon
            font.pixelSize: 16
            Layout.preferredWidth: 16
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            visible: root.hasSubmenu
            text: "›"                    // ›
            color: root.iconColor
            font.family: Theme.fontSans
            font.pixelSize: 18
        }
    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.disabled
        onContainsMouseChanged: root.hoveredChanged2(containsMouse)
        onClicked: root.clicked()
    }
}
