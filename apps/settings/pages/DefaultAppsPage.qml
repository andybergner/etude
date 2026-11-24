import QtQuick
import Etude.Ui
import "../components"

// Apps › Standard-Apps (wie Windows 11): je Art die App wählen, die Links und Dateien öffnet.
// Gespeichert in ~/.config/mimeapps.list (gilt für alle Apps, die xdg-open benutzen).
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var apps            // AppManager.qml

    spacing: 4

    Component.onCompleted: apps.refresh()

    Text {
        width: root.width
        bottomPadding: 8
        wrapMode: Text.Wrap
        text: tr.t("defaults.chooseWhichAppOpensLinks")
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }

    Repeater {
        model: root.apps.defaultKinds
        SettingRow {
            id: row
            required property var modelData
            readonly property var options: root.apps.candidates(modelData)
            readonly property string current: root.apps.currentDefault(modelData)
            width: root.width
            chevron: false
            icon: String.fromCodePoint(modelData.icon)
            label: modelData.label
            desc: modelData.desc

            Select {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.options.length > 0
                width: 240
                placeholder: tr.t("defaults.noAppSet")
                model: row.options.map(a => ({ value: a.id, label: a.name }))
                value: row.current
                onActivated: (v) => root.apps.setDefault(row.modelData, v)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.options.length === 0
                text: tr.t("defaults.noSuitableAppInstalled")
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 13
            }
        }
    }
}
