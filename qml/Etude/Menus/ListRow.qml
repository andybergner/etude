import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Listeneintrag in den Detailseiten: Icon, Titel, Untertitel, rechts Text/Icon.
// Optional aufklappbarer Bereich darunter (z. B. Passwort-Eingabe).
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""          // Icon-Glyphe rechts, z. B. Haken
    property bool active: false            // hervorgehoben (verbunden/ausgewählt)
    property bool expanded: false
    default property alias extra: extraCol.data

    signal clicked()

    implicitHeight: 48 + (expanded ? extraCol.implicitHeight + 8 : 0)
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: "transparent"
        HoverLayer { shown: root.expanded || root.active || mouse.containsMouse; level: root.expanded || root.active ? 1 : 0.6 }
    }

    RowLayout {
        id: head
        x: 10; width: parent.width - 20; height: 48
        spacing: 12
        Text {
            text: root.icon
            color: Theme.foreground
            font.family: Theme.fontIcon
            font.pixelSize: 18
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
        }
        Column {
            Layout.fillWidth: true
            Text { width: parent.width; text: root.title; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: root.active ? Font.Medium : Font.Normal; elide: Text.ElideRight }
            Text { width: parent.width; visible: root.subtitle !== ""; text: root.subtitle; color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 11; elide: Text.ElideRight }
        }
        Text {
            visible: root.trailing !== ""
            text: root.trailing
            color: Theme.foreground
            font.family: Theme.fontIcon
            font.pixelSize: 16
        }
    }
    MouseArea {
        id: mouse
        x: 0; width: parent.width; height: 48
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Column {
        id: extraCol
        x: 42; y: 48
        width: parent.width - 52
        spacing: 8
        visible: root.expanded
    }
}
