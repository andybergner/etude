import QtQuick
import Etude.Ui

// Umschalter mit mehreren Optionen (wie shadcn ToggleGroup / Tabs-Liste)
//   Segmented { options: [{ value: "bottom", label: "Unten" }, …]; value: "bottom" }
Rectangle {
    id: root

    property var options: []
    property string value: ""
    signal selected(string value)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 34
    radius: Theme.radiusMd
    color: Theme.muted

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property bool active: root.value === modelData.value
                width: label.implicitWidth + 24
                height: 28
                radius: Theme.radiusSm
                color: active ? Theme.background : (mouse.containsMouse ? Theme.alpha(Theme.background, 0.4) : Theme.alpha(Theme.background, 0))
                border.width: active ? 1 : 0
                border.color: Theme.border
                Behavior on color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.active ? Theme.foreground : Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(opt.modelData.value)
                }
            }
        }
    }
}
