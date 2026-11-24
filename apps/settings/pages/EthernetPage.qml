import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet › Ethernet (wie Windows 11):
// Status oben, IP-Zuweisung und DNS mit I18n.t("common.edit"), darunter Eigenschaften zum Kopieren
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var network        // Etude.Services/Network
    readonly property bool connected: network.kind === "ethernet"
    readonly property var info: network.info || {}
    readonly property var ip: network.ipConfig || {}

    spacing: 4

    Component.onCompleted: network.refresh()
    // IP-Einstellungen der aktiven Kabelverbindung laden
    onInfoChanged: if (connected && info.name && ip.connection !== info.name) network.loadIpConfig(info.name)

    function g(cp) { return String.fromCodePoint(cp) }

    // ===== Status =====
    SettingRow {
        width: root.width
        chevron: false
        icon: g(root.connected ? 0xF0200 : 0xF0A8E)
        label: root.connected ? (root.info.name || tr.t("ethernet.wiredConnection")) : tr.t("ethernet.notConnected")
        desc: root.connected ? (root.info.speed ? tr.t("ethernet.connectedSpeed").arg(root.info.speed) : tr.t("ethernet.connected"))
                             : tr.t("ethernet.noNetworkCablePluggedIn")
    }

    // ===== IP-Zuweisung =====
    SettingRow {
        visible: root.connected
        width: root.width
        chevron: false
        icon: g(0xF0A60)
        label: tr.t("ethernet.ipAssignment")
        desc: root.ip.method === "manual" ? tr.t("ethernet.manualValue").arg(root.ip.address) : tr.t("ethernet.automaticDhcp")
        Button {
            id: ipBtn
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: I18n.t("common.edit")
            onClicked: {
                ipMode.value = root.ip.method || "auto"
                ipAddr.text = root.ip.address || (root.info.ip || "")
                ipGw.text = root.ip.gateway || (root.info.gateway || "")
                ipPop.open()
            }
        }
    }

    Dialog {
        id: ipPop
        title: tr.t("ethernet.editIpSettings")
        description: tr.t("ethernet.automaticGetsTheAddressFrom")
        Segmented {
            id: ipMode
            options: [{ value: "auto", label: tr.t("ethernet.automaticDhcp2") }, { value: "manual", label: tr.t("ethernet.manual") }]
            value: "auto"
            onSelected: (v) => value = v
        }
        Field {
            visible: ipMode.value === "manual"
            width: parent.width
            label: tr.t("ethernet.ipAddressPrefix")
            hint: "z. B. 192.168.1.50/24"
            error: ipAddr.text !== "" && !/^\d+\.\d+\.\d+\.\d+\/\d+$/.test(ipAddr.text.trim()) ? tr.t("ethernet.format192168150") : ""
            Input { id: ipAddr; width: parent.width; placeholder: "192.168.1.50/24" }
        }
        Field {
            visible: ipMode.value === "manual"
            width: parent.width
            label: tr.t("ethernet.gateway")
            Input { id: ipGw; width: parent.width; placeholder: "192.168.1.1" }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: I18n.t("common.save")
                enabled: !root.network.busy && (ipMode.value === "auto" || /^\d+\.\d+\.\d+\.\d+\/\d+$/.test(ipAddr.text.trim()))
                onClicked: {
                    root.network.setIpConfig(root.info.name, {
                        method: ipMode.value, address: ipAddr.text.trim(),
                        gateway: ipGw.text.trim(), dns: root.ip.dnsAuto ? "" : root.ip.dns
                    })
                    ipPop.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: ipPop.close() }
        }
    }

    // ===== DNS =====
    SettingRow {
        visible: root.connected
        width: root.width
        chevron: false
        icon: g(0xF059F)
        label: tr.t("ethernet.dnsServerAssignment")
        desc: root.ip.dnsAuto || !root.ip.dns ? tr.t("ethernet.automaticDhcp") : tr.t("ethernet.manualValue").arg(root.ip.dns)
        Button {
            id: dnsBtn
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: I18n.t("common.edit")
            onClicked: {
                dnsMode.value = root.ip.dnsAuto || !root.ip.dns ? "auto" : "manual"
                dnsList.text = root.ip.dnsAuto ? "" : root.ip.dns
                dnsPop.open()
            }
        }
    }

    Dialog {
        id: dnsPop
        title: tr.t("ethernet.editDnsServers")
        Segmented {
            id: dnsMode
            options: [{ value: "auto", label: tr.t("ethernet.automaticDhcp2") }, { value: "manual", label: tr.t("ethernet.manual") }]
            value: "auto"
            onSelected: (v) => value = v
        }
        Field {
            visible: dnsMode.value === "manual"
            width: parent.width
            label: tr.t("ethernet.dnsServers")
            hint: tr.t("ethernet.separateMultipleWithCommas")
            Input { id: dnsList; width: parent.width; placeholder: "1.1.1.1, 9.9.9.9" }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: I18n.t("common.save")
                enabled: !root.network.busy
                onClicked: {
                    root.network.setIpConfig(root.info.name, {
                        method: root.ip.method, address: root.ip.address, gateway: root.ip.gateway,
                        dns: dnsMode.value === "manual" ? dnsList.text : ""
                    })
                    dnsPop.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: dnsPop.close() }
        }
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

    Item { visible: root.connected; width: 1; height: 8 }

    // ===== Eigenschaften =====
    InfoCard {
        visible: root.connected
        width: root.width
        title: tr.t("ethernet.properties")
        icon: g(0xF02FD)
        rows: [
            { label: tr.t("ethernet.connection"),      value: root.info.name || "" },
            { label: tr.t("ethernet.interface"),   value: root.info.iface || "" },
            { label: tr.t("ethernet.speed"), value: root.info.speed || "" },
            { label: tr.t("ethernet.ipv4Address"),    value: root.info.ip || "" },
            { label: tr.t("ethernet.ipv6Address"),    value: root.info.ip6 || "" },
            { label: tr.t("ethernet.gateway"),         value: root.info.gateway || "" },
            { label: tr.t("ethernet.dnsServers"),      value: root.info.dns || "" },
            { label: tr.t("ethernet.macAddress"),     value: root.info.mac || "" }
        ]
    }
}
