import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Kalender-Panel (Klick auf die Uhr) – reines QtQuick.
// Kopf wie im Startmenü: abgesetzt mit vollem Datum, darunter der Monatskalender.
Surface {
    id: root
    property Translations tr: Translations { domain: "calendar" }   // Texte dieses Moduls

    property date now: new Date()
    signal closeRequested()

    width: Theme.menuWidth
    height: col.implicitHeight + 2
    radius: Theme.radiusXl
    padding: 0
    focus: true
    Keys.onEscapePressed: root.closeRequested()

    function reset() { cal.today = now; cal.goToday() }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 1
        spacing: 0

        // ===== Kopf: "Mittwoch, 18. November" =====
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            color: Theme.alpha(Theme.muted, 0.5)
            topLeftRadius: root.radius - 1
            topRightRadius: root.radius - 1
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 12
                Column {
                    Layout.fillWidth: true
                    Text {
                        text: root.now.toLocaleDateString(I18n.locale, root.tr.t("calendar.dateFormat"))
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                    }
                    Text {
                        text: root.now.toLocaleTimeString(I18n.locale, root.tr.t("calendar.timeFormat"))
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans; font.pixelSize: 12
                    }
                }
                Button { text: root.tr.t("calendar.today"); variant: "outline"; size: "sm"; onClicked: cal.goToday() }
            }
        }

        // ===== Monatskalender =====
        Calendar {
            id: cal
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Layout.bottomMargin: 14
            today: root.now
        }
    }
}
