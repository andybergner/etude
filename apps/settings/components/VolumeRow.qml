import QtQuick
import Etude.Ui

// Zeile mit Stumm-Button, Slider und Prozentangabe
SettingRow {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property real volume: 0
    property bool muted: false
    property string iconOn: String.fromCodePoint(0xF057E)
    property string iconOff: String.fromCodePoint(0xF0581)

    signal moved(real value)
    signal muteClicked()

    chevron: false
    icon: ""                                   // Lautsprecher-Button sitzt rechts am Slider

    Button {
        anchors.verticalCenter: parent.verticalCenter
        variant: "ghost"
        size: "icon-sm"
        iconStart: root.muted ? root.iconOff : root.iconOn
        onClicked: root.muteClicked()
    }
    Slider {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(120, Math.min(260, root.width * 0.35))
        value: root.muted ? 0 : root.volume
        onMoved: (v) => root.moved(v)
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        horizontalAlignment: Text.AlignRight
        text: root.muted ? tr.t("sound.muted") : Math.round(root.volume * 100) + " %"
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
