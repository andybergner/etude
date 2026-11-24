import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet › WLAN › Bekannte Netzwerke verwalten
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var network        // Etude.Services/Network

    spacing: 4

    Component.onCompleted: network.scan()

    Repeater {
        model: network.known
        delegate: SettingRow {
            required property string modelData
            width: root.width
            chevron: false
            icon: String.fromCodePoint(0xF05A9)
            label: modelData
            desc: network.ssid === modelData ? tr.t("wifi.connected") : ""
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "outline"
                size: "sm"
                text: I18n.t("common.remove")
                onClicked: network.forget(modelData)
            }
        }
    }
    SettingRow {
        visible: network.known.length === 0
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF05A9)
        label: tr.t("wifi.noSavedWiFiNetworks")
    }
}
