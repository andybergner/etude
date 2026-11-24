import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet › VPN: eingerichtete VPN-/WireGuard-Verbindungen (NetworkManager)
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var network        // Etude.Services/Network

    spacing: 4

    Component.onCompleted: network.loadAdvanced()

    Repeater {
        model: network.vpns
        delegate: SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: String.fromCodePoint(0xF0582)
            label: modelData.name
            desc: modelData.type + (modelData.active ? " · " + tr.t("network.connected") : "")
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: modelData.active ? "outline" : "default"
                size: "sm"
                text: tr.t(modelData.active ? "devices.disconnect" : "devices.connect")
                enabled: !root.network.busy
                onClicked: root.network.vpnToggle(modelData.name, !modelData.active)
            }
        }
    }

    SettingRow {
        visible: network.vpns.length === 0
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0582)
        label: tr.t("vpn.noVpnConnectionSetUp")
        desc: tr.t("vpn.importWireguardNmcliConnectionImport")
    }

    Text {
        visible: root.network.lastError !== ""
        width: root.width
        topPadding: 4
        text: root.network.lastError
        wrapMode: Text.Wrap
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
