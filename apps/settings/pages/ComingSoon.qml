import QtQuick
import Etude.Ui

// Platzhalter für Seiten, die es noch nicht gibt
Rectangle {
    property Translations tr: Translations { domain: "settings" }   // Texte der App
    implicitHeight: 120
    radius: Theme.radiusMd
    color: Theme.card
    border.width: 1
    border.color: Theme.border

    Column {
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String.fromCodePoint(0xF1A0D)
            color: Theme.mutedForeground
            font.family: Theme.fontIcon
            font.pixelSize: 24
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tr.t("settings.thisPageIsStillBeing")
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
    }
}
