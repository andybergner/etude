import QtQuick
import Etude.Ui
import "../components"

// Datenschutz & Sicherheit › Standort: Standortdienst (geoclue) ein- und ausschalten.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var privacy         // Privacy.qml

    spacing: 4

    Component.onCompleted: privacy.refreshLocation()
    function g(cp) { return String.fromCodePoint(cp) }

    SettingRow {
        width: root.width
        chevron: false
        icon: root.g(root.privacy.geoEnabled ? 0xF034E : 0xF0350)
        label: tr.t("location.locationServices")
        desc: !root.privacy.geoInstalled ? tr.t("location.noLocationServiceInstalledApps")
            : root.privacy.geoEnabled ? (root.privacy.geoActive ? tr.t("location.onCurrentlyUsedByAn") : tr.t("location.onAppsMayRequestYour"))
            : tr.t("location.offAppsDontGetA")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.privacy.geoInstalled
            checked: root.privacy.geoEnabled
            enabled_: !root.privacy.geoBusy
            onToggled: root.privacy.setLocation(!root.privacy.geoEnabled)
        }
    }

    Text {
        width: root.width
        topPadding: 8
        wrapMode: Text.Wrap
        text: tr.t("location.explanation")
        color: Theme.mutedForeground
        font.family: Theme.fontSans; font.pixelSize: 13
    }
}
