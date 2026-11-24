import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet (Aufbau wie Windows 11):
// oben die aktuelle Verbindung mit tr.t("network.properties"), darunter WLAN, Ethernet, VPN, Proxy, Erweitert
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var network        // Etude.Services/Network
    signal navigate(string path)

    spacing: 4

    Component.onCompleted: { network.refresh(); network.loadAdvanced() }

    function g(cp) { return String.fromCodePoint(cp) }
    function signalIcon(s) {
        return g(s >= 75 ? 0xF0928 : s >= 50 ? 0xF0925 : s >= 25 ? 0xF0922 : 0xF091F)
    }
    readonly property var info: network.info || {}
    readonly property int vpnActive: network.vpns.filter(v => v.active).length

    // ===== Aktuelle Verbindung =====
    Rectangle {
        width: root.width
        height: 96
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Rectangle {
                width: 56; height: 56
                radius: Theme.radiusLg
                color: network.kind === "none" ? Theme.muted : Theme.primary
                Text {
                    anchors.centerIn: parent
                    text: network.kind === "ethernet" ? root.g(0xF0200)
                        : network.kind === "wifi" ? root.signalIcon(network.signal) : root.g(0xF0A8E)
                    color: network.kind === "none" ? Theme.mutedForeground : Theme.primaryForeground
                    font.family: Theme.fontIcon
                    font.pixelSize: 28
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    // welches Netz
                    text: network.kind === "ethernet" ? (root.info.name || tr.t("network.ethernet"))
                        : network.kind === "wifi" ? network.ssid : tr.t("network.notConnected")
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    text: network.kind === "ethernet" ? tr.t("network.ethernetConnected")
                        : network.kind === "wifi" ? tr.t("network.wiFiConnected")
                        : tr.t("network.plugInACableOr")
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }
        }

        Button {
            visible: network.kind !== "none" && root.width > 460
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("network.properties")
            iconStart: root.g(0xF02FD)
            onClicked: root.navigate(network.kind === "wifi" ? "network/wifi" : "network/ethernet")
        }
    }

    Item { width: 1; height: 8 }

    // ===== WLAN (mit Schalter) =====
    SettingRow {
        visible: network.hasWifi
        width: root.width
        icon: root.g(network.wifiEnabled ? 0xF05A9 : 0xF05AA)
        label: tr.t("nav.network.wifi")
        desc: !network.wifiEnabled ? I18n.t("common.off")
            : network.kind === "wifi" ? tr.t("network.connectedTo").arg(network.ssid) : tr.t("nav.network.wifiDesc")
        onClicked: root.navigate("network/wifi")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: network.wifiEnabled
            onToggled: network.setWifi(!network.wifiEnabled)
        }
    }

    SettingRow {
        width: root.width
        icon: root.g(0xF0200)
        label: tr.t("network.ethernet")
        desc: network.kind === "ethernet" ? tr.t("network.connectedIpAddressDns") : tr.t("network.notConnected")
        onClicked: root.navigate("network/ethernet")
    }

    SettingRow {
        width: root.width
        icon: root.g(0xF0582)
        label: "VPN"
        desc: root.vpnActive > 0 ? tr.t("network.connected") : (network.vpns.length > 0 ? tr.t("network.vpnCount").arg(network.vpns.length) : tr.t("network.vpnDesc"))
        onClicked: root.navigate("network/vpn")
    }

    SettingRow {
        width: root.width
        icon: root.g(0xF059F)
        label: tr.t("nav.network.proxy")
        desc: tr.t("nav.network.proxyDesc")
        onClicked: root.navigate("network/proxy")
    }

    SettingRow {
        width: root.width
        icon: root.g(0xF0493)
        label: tr.t("nav.network.advanced")
        desc: tr.t("network.showEnableAndDisableNetwork")
        onClicked: root.navigate("network/advanced")
    }
}
