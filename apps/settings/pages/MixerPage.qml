import QtQuick
import Etude.Ui
import "../components"

// System › Sound › Lautstärkemixer (wie Windows): System oben, darunter jede App
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var audio          // Etude.Services/Audio

    spacing: 4

    SectionTitle { text: tr.t("mixer.system"); topPadding: 0 }

    VolumeRow {
        visible: root.audio.ready
        width: root.width
        label: root.audio.sinks.find(s => s.active) ? root.audio.sinks.find(s => s.active).name : tr.t("mixer.output")
        volume: root.audio.volume
        muted: root.audio.muted
        onMoved: (v) => root.audio.set(v)
        onMuteClicked: root.audio.toggleMute()
    }

    SectionTitle { text: tr.t("mixer.apps") }

    Repeater {
        model: root.audio.streams
        delegate: VolumeRow {
            required property var modelData
            width: root.width
            label: modelData.name
            volume: modelData.volume
            muted: modelData.muted
            onMoved: (v) => root.audio.setStream(modelData.id, v)
            onMuteClicked: root.audio.toggleStreamMute(modelData.id)
        }
    }
    SettingRow {
        visible: root.audio.streams.length === 0
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0387)
        label: tr.t("mixer.noAppIsPlayingSound")
        desc: tr.t("mixer.asSoonAsAnApp")
    }
}
