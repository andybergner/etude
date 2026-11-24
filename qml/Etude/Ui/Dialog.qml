import QtQuick
import QtQuick.Templates as T

// shadcn: Dialog – Karte in der Mitte, Rest abgedunkelt, Esc oder Klick daneben schließt.
//   Button { text: "Ändern"; onClicked: dlg.open() }
//   Dialog { id: dlg; title: "Kennwort ändern"; description: "…"
//            Field { … }
//            Row { layoutDirection: Qt.RightToLeft; Button { text: "Speichern" } } }
//
// Abdunklung und Karte liegen bewusst im contentItem: background/Overlay.modal
// des Popups werden im Quickshell-Fenster nicht zuverlässig gezeichnet.
T.Popup {
    id: root

    property string title: ""
    property string description: ""
    property real cardWidth: 440
    default property alias content: body.data

    parent: T.Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: true
    dim: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape
    background: null

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
            NumberAnimation { target: card; property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
            NumberAnimation { target: card; property: "scale"; from: 1; to: 0.95; duration: 120 }
        }
    }

    contentItem: Item {
        // abgedunkelter Hintergrund (shadcn: bg-black/50), Klick daneben schließt
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.close()
                onWheel: wheel => wheel.accepted = true
            }
        }

        // Karte: deckend (auch bei Transparenz), rounded-lg, border, Schatten
        Rectangle {
            id: card
            width: Math.min(root.cardWidth, parent.width - 32)
            height: col.implicitHeight + 48
            x: Math.round((parent.width - width) / 2)
            y: Math.max(16, Math.round((parent.height - height) / 2.4))
            radius: Theme.radiusLg
            color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
            border.width: 1
            border.color: Theme.border

            // weicher, gleichmäßiger Schatten rundherum (kein Versatz nach unten)
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    z: -1
                    anchors.fill: parent
                    anchors.margins: -(index + 1)
                    radius: card.radius + index + 1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.16 : 0.05) * (1 - index / 6))
                }
            }

            // Klicks in der Karte nicht an die Abdunklung weitergeben
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Column {
                id: col
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 20

                Column {
                    visible: root.title !== "" || root.description !== ""
                    width: parent.width
                    spacing: 6
                    Text {
                        visible: root.title !== ""
                        width: parent.width
                        text: root.title
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Text {
                        visible: root.description !== ""
                        width: parent.width
                        text: root.description
                        wrapMode: Text.Wrap
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                    }
                }

                Column {
                    id: body
                    width: parent.width
                    spacing: 14
                }
            }
        }
    }
}
