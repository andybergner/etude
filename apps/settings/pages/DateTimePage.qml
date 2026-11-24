import QtQuick
import Etude.Ui
import "../components"

// Zeit & Sprache › Datum und Uhrzeit
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var timedate      // TimeDate.qml
    required property var config        // EtudeConfig
    property date now: new Date()

    spacing: 4

    Component.onCompleted: { timedate.refresh(); timedate.loadLists() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // Aktuelle Zeit groß (wie Windows)
    Column {
        bottomPadding: 16
        spacing: 2
        Text {
            text: root.now.toLocaleTimeString(I18n.locale, root.config.clock24 ? "HH:mm:ss" : "h:mm:ss AP")
            color: Theme.foreground
            font.family: Theme.fontSans
            font.pixelSize: 32
            font.weight: Font.DemiBold
        }
        Text {
            text: root.now.toLocaleDateString(I18n.locale, Locale.LongFormat) + "  ·  " + (root.timedate.timezone || "")
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF04E6)
        label: tr.t("datetime.setTimeAutomatically")
        desc: tr.t("datetime.synchronizeOverTheInternetNtp")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.timedate.ntp
            onToggled: root.timedate.setNtp(!root.timedate.ntp)
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF01E7)
        label: tr.t("datetime.timeZone")
        desc: tr.t("datetime.appliesToTheWholeSystem")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(280, root.width * 0.4)
            model: root.timedate.timezones.map(tz => ({ value: tz, label: tz.replace(/_/g, " ") }))
            value: root.timedate.timezone
            searchable: true
            onActivated: (v) => root.timedate.setTimezone(v)
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

    SectionTitle { text: tr.t("datetime.clockInTheTaskbar") }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0150)
        label: tr.t("datetime.24HourFormat")
        desc: tr.t(root.config.clock24 ? "datetime.example24" : "datetime.example12")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.clock24
            onToggled: root.config.set("clock24", !root.config.clock24)
        }
    }
    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0150)
        label: tr.t("datetime.showSeconds")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.clockSeconds
            onToggled: root.config.set("clockSeconds", !root.config.clockSeconds)
        }
    }
}
