import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Rahmen für die Menüs der Leiste (Netzwerk, Bluetooth, Lautsprecher, Akku):
// Kopf mit Titel und optional Schalter, scrollbarer Inhalt, Fußzeile mit Link.
// Die Höhe richtet sich nach dem Inhalt (höchstens maxBodyHeight).
Surface {
    id: root

    property string title: ""
    property bool hasSwitch: false
    property bool switchOn: false
    property string footerText: ""
    property real maxBodyHeight: 380
    default property alias content: body.data

    signal switchToggled()
    signal footerClicked()

    width: Theme.menuWidth
    height: head.height + flick.height + (foot.visible ? foot.height : 0) + 2
    radius: Theme.radiusXl
    padding: 0

    Column {
        anchors.fill: parent
        anchors.margins: 1

        // Kopf (abgesetzt wie Startmenü und Kalender)
        Rectangle {
            id: head
            width: parent.width
            height: 52
            color: Theme.alpha(Theme.muted, 0.5)
            topLeftRadius: root.radius - 1
            topRightRadius: root.radius - 1
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.foreground
                    font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                }
                Switch { visible: root.hasSwitch; checked: root.switchOn; onToggled: root.switchToggled() }
            }
        }

        // Inhalt
        Flickable {
            id: flick
            x: 8
            width: parent.width - 16
            height: Math.min(body.childrenRect.height + 16, root.maxBodyHeight)
            clip: true
            contentWidth: width
            contentHeight: body.childrenRect.height + 16
            boundsBehavior: Flickable.StopAtBounds
            Item { id: body; y: 8; width: flick.width }
        }

        // Fußzeile
        Rectangle {
            id: foot
            visible: root.footerText !== ""
            width: parent.width
            height: 44
            color: Theme.alpha(Theme.muted, 0.5)
            bottomLeftRadius: root.radius - 1
            bottomRightRadius: root.radius - 1
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.border }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.footerText
                color: footMouse.containsMouse ? Theme.foreground : Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 12
                font.underline: footMouse.containsMouse
            }
            MouseArea { id: footMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.footerClicked() }
        }
    }
}
