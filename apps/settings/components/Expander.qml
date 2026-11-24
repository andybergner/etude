import QtQuick
import Etude.Ui

// Aufklappbare Karte (wie Windows 11): Kopfzeile mit Icon, Titel, Beschreibung und Pfeil,
// darunter der Inhalt. Inhalt einfach als Kinder angeben.
//   Expander { icon: "…"; label: "Wiedergabegerät"; desc: "Lautsprecher"; expanded: true
//              SettingRow { … } }
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string desc: ""
    property bool expanded: false
    default property alias content: body.data

    implicitHeight: header.height + (expanded ? body.implicitHeight + 1 : 0)
    clip: true
    radius: Theme.radiusMd
    color: Theme.card
    border.width: 1
    border.color: Theme.border
    Behavior on implicitHeight { enabled: Theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Kopfzeile
    Item {
        id: header
        width: parent.width
        height: root.desc ? 64 : 52
        HoverLayer { radius: Theme.radiusMd; shown: headMouse.containsMouse }

        // Tastatur: Tab/Pfeile erreichen die Kopfzeile, Enter/Leertaste klappt auf/zu
        activeFocusOnTab: true
        Keys.onReturnPressed: root.expanded = !root.expanded
        Keys.onEnterPressed: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded
        Keys.onPressed: (e) => FocusNav.key(header, e)  // Pfeiltasten: zum Nachbarn
        readonly property bool ownFocusRing: true
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: "transparent"
            border.width: 2
            border.color: Theme.ring
            visible: header.activeFocus
            z: 5
        }

        Text {
            id: ico
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            text: root.icon
            color: Theme.foreground
            font.family: Theme.fontIcon
            font.pixelSize: 18
        }
        Column {
            anchors.left: ico.right
            anchors.leftMargin: 16
            anchors.right: chev.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: root.label
                elide: Text.ElideRight
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 14
            }
            Text {
                width: parent.width
                visible: root.desc !== ""
                text: root.desc
                elide: Text.ElideRight
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 12
            }
        }
        Text {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0140)                    // chevron-down
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 180 } }
            color: Theme.mutedForeground
            font.family: Theme.fontIcon
            font.pixelSize: 18
        }
        MouseArea {
            id: headMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {                                                    // Trennlinie
        visible: root.expanded
        y: header.height
        width: parent.width; height: 1
        color: Theme.border
    }

    Column {
        id: body
        visible: root.expanded || root.height > header.height + 1   // zugeklappt: nicht per Tab/Pfeil erreichbar
        y: header.height + 1
        width: parent.width
    }
}
