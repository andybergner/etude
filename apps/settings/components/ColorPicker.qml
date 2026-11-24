import QtQuick
import Etude.Ui

// Farbwähler: Kacheln mit Haken und Tooltip (Akzentfarbe, Hintergrund-Farbton …)
//   ColorPicker { colors: [{ value: "#3b82f6", label: "Blau" }, …]; value: "#3b82f6"
//                 onSelected: (v) => … }
// value "" ist erlaubt (z. B. "Standard") – dann zeigt die Kachel "fallback".
Rectangle {
    id: root

    property var colors: []
    property string value: ""
    property color fallback: Theme.dark ? "#e4e4e7" : "#18181b"
    signal selected(string value)

    implicitHeight: flow.implicitHeight + 32
    radius: Theme.radiusMd
    color: Theme.card
    border.width: 1
    border.color: Theme.border

    Flow {
        id: flow
        x: 20; y: 16
        width: parent.width - 40
        spacing: 10
        Repeater {
            model: root.colors
            delegate: Rectangle {
                id: sw
                required property var modelData
                readonly property bool active: root.value.toLowerCase() === modelData.value.toLowerCase()
                z: mouse.containsMouse ? 1 : 0          // Tooltip über den Nachbarn
                width: 40; height: 40
                radius: Theme.radiusMd
                color: modelData.value || root.fallback
                border.width: active ? 2 : 1
                border.color: active ? Theme.foreground : Theme.border
                scale: mouse.containsMouse && !active ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: Theme.duration } }

                Text {
                    visible: sw.active
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF012C)
                    color: Theme.luminance(sw.color) > 0.6 ? "#18181b" : "#fafafa"
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(sw.modelData.value)
                }
                Tooltip { text: sw.modelData.label; shown: mouse.containsMouse }
            }
        }
    }
}
