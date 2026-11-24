import QtQuick
import Etude.Ui
import "../components"
import "../components/Languages.js" as Languages

// Zeit & Sprache › Tastatur (wirkt sofort über Hyprland)
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var hypr          // HyprSettings.qml

    spacing: 4

    readonly property string current: hypr.kbLayout + (hypr.kbVariant ? ":" + hypr.kbVariant : "")

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF030C)
        label: tr.t("keyboard.keyboardLayout")
        desc: tr.t("keyboard.appliesToAllWindowsImmediately")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(280, root.width * 0.4)
            model: Languages.keyboardsT(tr)
            value: root.current
            onActivated: (v) => {
                const [layout, variant] = v.split(":")
                root.hypr.setKeyboard(layout, variant || "")
            }
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF03A0)
        label: tr.t("keyboard.turnOnNumLockAt")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.hypr.numlock
            onToggled: root.hypr.setNumlock(!root.hypr.numlock)
        }
    }

    SectionTitle { text: tr.t("keyboard.test") }

    Rectangle {
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Input {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 16
            anchors.verticalCenter: parent.verticalCenter
            placeholder: tr.t("keyboard.typeHereToTestThe")
        }
    }
}
