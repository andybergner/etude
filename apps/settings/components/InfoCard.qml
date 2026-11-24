import QtQuick
import Quickshell
import Etude.Ui

// Karte mit Überschrift, tr.t("info.copy")-Button und Eigenschaften (wie Windows › Info)
//   InfoCard { title: "Gerätespezifikationen"; icon: "…"; rows: [{ label, value }, …] }
Rectangle {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string title: ""
    property string icon: ""
    property var rows: []
    property bool copyable: true

    readonly property var visibleRows: rows.filter(r => r.value)

    implicitHeight: col.implicitHeight + 8
    radius: Theme.radiusMd
    color: Theme.card
    border.width: 1
    border.color: Theme.border

    Column {
        id: col
        y: 4
        width: parent.width

        // Kopfzeile
        Item {
            width: parent.width
            height: 52
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: root.icon
                    color: Theme.foreground
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }
            Button {
                id: copyBtn
                visible: root.copyable
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                variant: "outline"
                size: "sm"
                text: copied.running ? tr.t("info.copied") : tr.t("info.copy")
                iconStart: String.fromCodePoint(copied.running ? 0xF012C : 0xF018F)
                onClicked: {
                    const txt = root.title + "\n" + root.visibleRows.map(r => r.label + ": " + r.value).join("\n")
                    Quickshell.clipboardText = txt
                    copied.restart()
                }
                Timer { id: copied; interval: 1500 }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Repeater {
            model: root.visibleRows
            delegate: InfoRow {
                required property var modelData
                width: col.width
                label: modelData.label
                value: modelData.value
            }
        }
        Item { width: 1; height: 4 }
    }
}
