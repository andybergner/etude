import QtQuick
import Quickshell
import Etude.Ui
import "../components"

// Datenschutz & Sicherheit › Mikrofon (wie Windows 11):
// Hauptschalter und welche Apps gerade aufnehmen.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var audio           // Etude.Services/Audio
    signal navigate(string path)

    spacing: 4

    function g(cp) { return String.fromCodePoint(cp) }

    SettingRow {
        width: root.width
        chevron: false
        icon: root.g(root.audio.sourceMuted ? 0xF036D : 0xF036C)
        label: tr.t("microphone.microphoneAccess")
        desc: root.audio.sourceMuted ? tr.t("microphone.offAppsOnlyGetSilence") : tr.t("microphone.onAppsCanUseThe")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: !root.audio.sourceMuted
            enabled_: root.audio.sourceReady
            onToggled: root.audio.toggleSourceMute()
        }
    }

    SectionTitle { text: tr.t("microphone.currentlyUsedBy") }

    Rectangle {
        visible: root.audio.recording.length === 0
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: tr.t("microphone.noAppIsUsingThe")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 13
        }
    }

    Repeater {
        model: root.audio.recording
        SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: root.g(0xF036C)
            iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
            label: modelData.name
            desc: tr.t("microphone.recordingRightNow")
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: Theme.primary
            }
        }
    }

    SectionTitle { text: tr.t("microphone.relatedSettings") }
    SettingRow {
        width: root.width
        icon: root.g(0xF057E)
        label: tr.t("microphone.sound")
        desc: tr.t("microphone.microphoneInputDeviceAndVolume")
        onClicked: root.navigate("system/sound")
    }
}
