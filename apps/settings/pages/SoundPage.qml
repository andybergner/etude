import QtQuick
import Etude.Ui
import "../components"

// System › Sound (Aufbau wie Windows 11):
//   Ausgabe:  Wiedergabegerät (aufklappbar) + Lautstärke
//   Eingabe:  Aufnahmegerät (aufklappbar) + Lautstärke
//   Erweitert: Lautstärkemixer, Bluetooth-Gerät koppeln
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var audio          // Etude.Services/Audio
    signal navigate(string path)

    spacing: 4

    function g(cp) { return String.fromCodePoint(cp) }
    function deviceIcon(kind) {
        return g(kind === "headphones" ? 0xF02CB : kind === "monitor" ? 0xF0379 : 0xF04C3)
    }
    readonly property var activeSink: audio.sinks.find(s => s.active)
    readonly property var activeSource: audio.sources.find(s => s.active)

    // ===== Ausgabe =====
    SectionTitle { text: tr.t("sound.output"); topPadding: 0 }

    Expander {
        width: root.width
        icon: root.activeSink ? root.deviceIcon(root.activeSink.kind) : g(0xF0581)
        label: tr.t("sound.chooseAPlaybackDevice")
        desc: root.activeSink ? root.activeSink.name : tr.t("sound.noOutputDeviceFound")

        Repeater {
            model: root.audio.sinks
            delegate: ChoiceRow {
                required property var modelData
                width: root.width
                icon: root.deviceIcon(modelData.kind)
                label: modelData.name
                checked: modelData.active
                onClicked: root.audio.select(modelData.id)
            }
        }
        ChoiceRow {
            visible: root.audio.sinks.length === 0
            width: root.width
            label: tr.t("sound.noDeviceInAVm")
        }
    }

    VolumeRow {
        visible: root.audio.ready
        width: root.width
        label: tr.t("sound.volume")
        volume: root.audio.volume
        muted: root.audio.muted
        onMoved: (v) => root.audio.set(v)
        onMuteClicked: root.audio.toggleMute()
    }

    // ===== Eingabe =====
    SectionTitle { text: tr.t("sound.input") }

    Expander {
        width: root.width
        icon: g(root.activeSource ? 0xF036C : 0xF036D)
        label: tr.t("sound.chooseADeviceForSpeaking")
        desc: root.activeSource ? root.activeSource.name : tr.t("sound.noMicrophoneFound")

        Repeater {
            model: root.audio.sources
            delegate: ChoiceRow {
                required property var modelData
                width: root.width
                icon: root.g(0xF036C)
                label: modelData.name
                checked: modelData.active
                onClicked: root.audio.selectSource(modelData.id)
            }
        }
        ChoiceRow {
            visible: root.audio.sources.length === 0
            width: root.width
            label: tr.t("sound.noMicrophoneConnected")
        }
    }

    VolumeRow {
        visible: root.audio.sourceReady
        width: root.width
        label: tr.t("sound.volume")
        iconOn: g(0xF036C)
        iconOff: g(0xF036D)
        volume: root.audio.sourceVolume
        muted: root.audio.sourceMuted
        onMoved: (v) => root.audio.setSource(v)
        onMuteClicked: root.audio.toggleSourceMute()
    }

    // ===== Erweitert =====
    SectionTitle { text: tr.t("sound.advanced") }

    SettingRow {
        width: root.width
        icon: g(0xF0387)
        label: tr.t("nav.system.sound.mixer")
        desc: root.audio.streams.length > 0
              ? tr.tn("sound.appsPlaying", root.audio.streams.length).arg(root.audio.streams.length)
              : tr.t("nav.system.sound.mixerDesc")
        onClicked: root.navigate("system/sound/mixer")
    }
    SettingRow {
        width: root.width
        icon: g(0xF00AF)
        label: tr.t("sound.pairANewAudioDevice")
        desc: tr.t("sound.connectBluetoothHeadphonesOrSpeakers")
        onClicked: root.navigate("bluetooth")
    }
}
