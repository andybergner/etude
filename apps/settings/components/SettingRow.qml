import QtQuick
import Etude.Ui

// Karte/Zeile mit Icon, Titel, Beschreibung und Pfeil (wie Windows 11).
// Eigene Steuerelemente (Switch, Slider …) rechts über "trailing".
Item {
    id: root

    property string icon: ""
    property string iconSource: ""        // Bild statt Glyph (z. B. App-Icon)
    property string label: ""
    property string desc: ""
    property bool chevron: true
    property bool clickable: chevron      // ganze Zeile klickbar (auch ohne Pfeil)
    default property alias trailing: trail.data

    signal clicked()

    implicitHeight: desc !== "" ? 64 : 52

    // Tastatur: klickbare Zeilen erreicht man per Tab/Pfeilen, Enter/Leertaste öffnet
    activeFocusOnTab: clickable
    Keys.onReturnPressed: if (clickable) clicked()
    Keys.onEnterPressed: if (clickable) clicked()
    Keys.onSpacePressed: if (clickable) clicked()
    Keys.onPressed: (e) => FocusNav.key(root, e)        // Pfeiltasten: zum Nachbarn
    readonly property bool ownFocusRing: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        HoverLayer { shown: mouse.containsMouse && root.clickable }
    }
    Rectangle {                                   // Fokus-Ring (Tastatur)
        anchors.fill: parent
        radius: Theme.radiusMd
        color: "transparent"
        border.width: 2
        border.color: Theme.ring
        visible: root.activeFocus
        z: 5
    }

    Item {
        id: ico
        readonly property bool has: root.icon !== "" || root.iconSource !== ""
        anchors.left: parent.left
        anchors.leftMargin: has ? 20 : 4
        anchors.verticalCenter: parent.verticalCenter
        width: has ? 20 : 0
        height: 20
        Text {
            anchors.centerIn: parent
            visible: root.iconSource === "" || img.status !== Image.Ready
            text: root.icon
            color: Theme.foreground
            font.family: Theme.fontIcon
            font.pixelSize: 18
        }
        Image {
            id: img
            anchors.fill: parent
            visible: status === Image.Ready
            source: root.iconSource
            sourceSize: Qt.size(40, 40)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }

    Column {
        anchors.left: ico.right
        anchors.leftMargin: 16
        anchors.right: trail.left
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

    Row {
        id: trail
        z: 2                                   // Bedienelemente über der Klickfläche
        anchors.right: chev.visible ? chev.left : parent.right
        anchors.rightMargin: chev.visible ? 12 : 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }

    Text {
        id: chev
        visible: root.chevron
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: String.fromCodePoint(0xF0142)
        color: Theme.mutedForeground
        font.family: Theme.fontIcon
        font.pixelSize: 16
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
