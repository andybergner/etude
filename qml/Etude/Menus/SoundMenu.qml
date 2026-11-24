import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Lautsprecher-Menü: laufende Wiedergabe, Lautstärke, Ausgabegerät wählen
MenuPage {
    id: root
    property Translations tr: Translations { domain: "menus" }   // Texte dieses Moduls

    property real volume: 0.5
    property bool muted: false
    property var sinks: []              // [{ id, name, kind, active }]
    property bool hasMedia: false
    property string mediaApp: ""
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool mediaPlaying: false

    signal setVolume(real v)
    signal toggleMute()
    signal selectSink(int id)
    signal mediaPrevious()
    signal mediaPlayPause()
    signal mediaNext()
    signal openSettings()

    title: tr.t("menus.volume")
    footerText: tr.t("menus.soundSettings")
    onFooterClicked: root.openSettings()

    function g(cp) { return String.fromCodePoint(cp) }
    function icon(kind) { return kind === "headphones" ? g(0xF02CB) : kind === "monitor" ? g(0xF0379) : g(0xF04C3) }

    Column {
        width: parent.width
        spacing: 2

        // Wiedergabe (nur wenn etwas läuft)
        Rectangle {
            visible: root.hasMedia
            width: parent.width
            height: 64
            radius: Theme.radiusMd
            color: Theme.alpha(Theme.muted, 0.6)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 6
                spacing: 4
                Column {
                    Layout.fillWidth: true
                    Text { width: parent.width; text: root.mediaTitle; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight }
                    Text { width: parent.width; text: root.mediaArtist + (root.mediaApp ? " · " + root.mediaApp : ""); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 11; elide: Text.ElideRight }
                }
                Button { variant: "ghost"; size: "icon-sm"; iconStart: root.g(0xF04AE); onClicked: root.mediaPrevious() }
                Button { variant: "ghost"; size: "icon-sm"; iconStart: root.mediaPlaying ? root.g(0xF03E4) : root.g(0xF040A); onClicked: root.mediaPlayPause() }
                Button { variant: "ghost"; size: "icon-sm"; iconStart: root.g(0xF04AD); onClicked: root.mediaNext() }
            }
        }

        // Lautstärke
        RowLayout {
            width: parent.width
            height: 44
            spacing: 8
            Button { variant: "ghost"; size: "icon-sm"; iconStart: root.muted ? root.g(0xF0581) : root.g(0xF057E); onClicked: root.toggleMute() }
            Slider { Layout.fillWidth: true; value: root.muted ? 0 : root.volume; onMoved: (v) => root.setVolume(v) }
            Text { Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; Layout.rightMargin: 8
                   text: root.muted ? "–" : Math.round(root.volume * 100); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
        }

        SectionLabel { text: root.tr.t("menus.outputDevice") }
        Text {
            visible: root.sinks.length === 0
            width: parent.width; padding: 10
            text: root.tr.t("menus.noOutputs")
            color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
        }
        Repeater {
            model: root.sinks
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: root.icon(modelData.kind)
                title: modelData.name
                active: modelData.active
                trailing: modelData.active ? root.g(0xF012C) : ""
                onClicked: root.selectSink(modelData.id)
            }
        }
    }
}
