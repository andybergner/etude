import QtQuick
import Etude.Ui

// Auswahlkarte mit kleiner Vorschau des Fenster-Layouts
Item {
    id: root

    property string label: ""
    property string desc: ""
    property var boxes: []               // [[x, y, w, h], …] in 0..1
    property bool selected: false

    signal clicked()

    implicitHeight: col.implicitHeight + 20

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.card
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Theme.primary : Theme.border
        HoverLayer { shown: mouse.containsMouse && !root.selected }
    }

    Column {
        id: col
        x: 10; y: 10
        width: parent.width - 20
        spacing: 8

        // Vorschau: "Bildschirm" mit Fenstern
        Rectangle {
            width: parent.width
            height: width * 0.56
            radius: Theme.radiusMd
            color: Theme.muted
            clip: true

            Item {
                anchors.fill: parent
                anchors.margins: 6
                Repeater {
                    model: root.boxes
                    Rectangle {
                        required property var modelData
                        required property int index
                        x: modelData[0] * parent.width + 2
                        y: modelData[1] * parent.height + 2
                        width: modelData[2] * parent.width - 4
                        height: modelData[3] * parent.height - 4
                        radius: 4
                        color: root.selected && index === 0 ? Theme.primary : Theme.alpha(Theme.foreground, 0.18 + index * 0.06)
                        border.width: 1
                        border.color: Theme.alpha(Theme.foreground, 0.25)
                    }
                }
            }
        }

        Row {
            spacing: 8
            // Auswahlkreis
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8
                color: "transparent"
                border.width: root.selected ? 5 : 1
                border.color: root.selected ? Theme.primary : Theme.input
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
        // immer 2 Zeilen hoch, damit alle Karten gleich groß sind
        Text {
            width: parent.width
            height: Math.ceil(font.pixelSize * 1.35) * 2
            text: root.desc
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
