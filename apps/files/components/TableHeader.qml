import QtQuick
import Etude.Ui

// Kopfzeile einer Tabelle mit sortierbaren Spalten (Klick = sortieren, nochmal = umdrehen).
//   columns: [{ key, label, width (px, 0 = Rest), align: "left"|"right", summary }]
Item {
    id: root

    property var columns: []
    property string sortKey: ""
    property bool sortDesc: true
    signal sortRequested(string key)

    implicitHeight: 44

    Row {
        anchors.fill: parent
        Repeater {
            model: root.columns
            Item {
                id: col
                required property var modelData
                readonly property real fixed: root.columns.reduce((s, c) => s + (c.width || 0), 0)
                width: modelData.width || Math.max(80, root.width - fixed)
                height: root.height

                HoverLayer { radius: 0; shown: ma.containsMouse; level: 0.5 }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 0
                    Text {
                        width: parent.width
                        visible: col.modelData.summary !== undefined && col.modelData.summary !== ""
                        horizontalAlignment: col.modelData.align === "right" ? Text.AlignRight : Text.AlignLeft
                        text: col.modelData.summary || ""
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    Row {
                        anchors.right: col.modelData.align === "right" ? parent.right : undefined
                        spacing: 4
                        Text {
                            text: col.modelData.label
                            color: root.sortKey === col.modelData.key ? Theme.foreground : Theme.mutedForeground
                            font.family: Theme.fontSans; font.pixelSize: 12
                            font.weight: root.sortKey === col.modelData.key ? Font.Medium : Font.Normal
                        }
                        Text {
                            visible: root.sortKey === col.modelData.key
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(root.sortDesc ? 0xF0140 : 0xF0143)
                            color: Theme.mutedForeground
                            font.family: Theme.fontIcon; font.pixelSize: 12
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 1; height: parent.height - 16; color: Theme.border }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortRequested(col.modelData.key)
                }
            }
        }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }
}
