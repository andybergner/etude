import QtQuick
import Etude.Ui
import "../components"
import "../Nav.js" as Nav

// Suchergebnisse aus allen Kategorien und Unterseiten
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string query: ""
    readonly property var results: Nav.search(query, tr)
    signal navigate(string path)

    spacing: 4

    Repeater {
        model: root.results
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate(modelData.path)
        }
    }

    Text {
        visible: root.results.length === 0
        topPadding: 8
        text: tr.t("settings.noSettingFound")
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }
}
