import QtQuick
import Etude.Ui
import "../components"
import "../Nav.js" as Nav

// Allgemeine Kategorieseite: Unterseiten als Zeilen, sonst "kommt bald"
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string category: ""
    signal navigate(string path)

    spacing: 4

    Repeater {
        model: Nav.pagesT(tr, root.category)
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate(root.category + "/" + modelData.id)
        }
    }

    ComingSoon {
        visible: !Nav.pagesT(tr, root.category).length
        width: root.width
    }
}
