import QtQuick
import Etude.Ui
import "../components"
import "../components/Languages.js" as Languages

// Zeit & Sprache › Sprache und Region
Column {
    id: root

    required property var timedate      // TimeDate.qml

    spacing: 4

    Component.onCompleted: { timedate.refresh(); timedate.loadLists() }

    Translations { id: tr; domain: "settings" }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF05CA)
        label: tr.t("language.systemLanguage")
        desc: tr.t("language.systemLanguageDesc")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(300, root.width * 0.45)
            model: Languages.localeOptions(root.timedate.locales)
            value: root.timedate.locale
            searchable: true
            onActivated: (v) => root.timedate.setLocale(v)
        }
    }

    Text {
        visible: root.timedate.error !== ""
        width: root.width
        topPadding: 4
        text: root.timedate.error
        wrapMode: Text.Wrap
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    Text {
        width: root.width
        topPadding: 8
        text: tr.t("language.missingHint")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
