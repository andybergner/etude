import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet › WLAN (wie Windows 11):
// Schalter, aktuelle Verbindung, tr.t("wifi.showAvailableNetworks"), tr.t("nav.network.wifi.known")
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var network        // Etude.Services/Network
    signal navigate(string path)
    property string pwFor: ""            // WLAN, für das gerade ein Passwort eingegeben wird

    spacing: 4

    Component.onCompleted: { network.refresh(); network.scan() }

    function g(cp) { return String.fromCodePoint(cp) }
    function signalIcon(s) {
        return g(s >= 75 ? 0xF0928 : s >= 50 ? 0xF0925 : s >= 25 ? 0xF0922 : 0xF091F)
    }

    SettingRow {
        visible: !network.hasWifi
        width: root.width
        chevron: false
        icon: g(0xF05AA)
        label: tr.t("wifi.noWiFiAdapterFound")
    }

    SettingRow {
        visible: network.hasWifi
        width: root.width
        chevron: false
        icon: g(network.wifiEnabled ? 0xF05A9 : 0xF05AA)
        label: tr.t("nav.network.wifi")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: network.wifiEnabled
            onToggled: network.setWifi(!network.wifiEnabled)
        }
    }

    // Aktuelle Verbindung
    SettingRow {
        visible: network.hasWifi && network.kind === "wifi"
        width: root.width
        chevron: false
        icon: root.signalIcon(network.signal)
        label: network.ssid
        desc: tr.t("wifi.connectedSignal").arg(network.signal) + (network.info.ip ? " · " + network.info.ip.split("/")[0] : "")
        Button {
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("wifi.disconnect")
            onClicked: network.disconnect(network.ssid)
        }
    }

    // Verfügbare Netzwerke
    Expander {
        visible: network.hasWifi && network.wifiEnabled
        width: root.width
        expanded: true
        icon: g(0xF0928)
        label: tr.t("wifi.showAvailableNetworks")
        desc: tr.tn("wifi.inRange", network.networks.length).arg(network.networks.length)

        Repeater {
            model: network.networks
            delegate: Column {
                id: wlan
                required property var modelData
                width: root.width

                Item {
                    width: parent.width
                    height: 52
                    HoverLayer { radius: 0; shown: rowMouse.containsMouse && !wlan.modelData.active }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.signalIcon(wlan.modelData.signal)
                            color: Theme.foreground
                            font.family: Theme.fontIcon
                            font.pixelSize: 16
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: wlan.modelData.ssid
                                color: Theme.foreground
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                            }
                            Text {
                                text: network.connecting === wlan.modelData.ssid ? tr.t("wifi.connecting")
                                    : wlan.modelData.active ? tr.t("wifi.connected")
                                    : tr.t(wlan.modelData.secure ? "wifi.secured" : "wifi.open") + (wlan.modelData.known ? " · " + tr.t("wifi.saved") : "")
                                color: Theme.mutedForeground
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                            }
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        z: 2
                        Text {
                            visible: wlan.modelData.secure
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.g(0xF033E)
                            color: Theme.mutedForeground
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                        }
                        Button {
                            visible: !wlan.modelData.active && network.connecting === ""
                            anchors.verticalCenter: parent.verticalCenter
                            variant: "outline"
                            size: "sm"
                            text: tr.t("wifi.connect")
                            onClicked: rowMouse.clicked(null)
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !wlan.modelData.active && network.connecting === ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (wlan.modelData.secure && !wlan.modelData.known) root.pwFor = wlan.modelData.ssid
                            else network.connect(wlan.modelData.ssid, "")
                        }
                    }
                }

                // Passwort direkt unter dem Netz
                Item {
                    visible: root.pwFor === wlan.modelData.ssid
                    width: parent.width
                    height: 56
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Input {
                            id: pw
                            width: parent.width - connectBtn.width - cancelBtn.width - 16
                            placeholder: tr.t("wifi.networkKey")
                            echoMode: TextInput.Password
                            onAccepted: connectBtn.clicked()
                            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                            onEscapePressed: root.pwFor = ""
                        }
                        Button {
                            id: connectBtn
                            text: tr.t("wifi.connect")
                            enabled: pw.text.length >= 8
                            onClicked: { network.connect(wlan.modelData.ssid, pw.text); root.pwFor = "" }
                        }
                        Button { id: cancelBtn; variant: "ghost"; text: I18n.t("common.cancel"); onClicked: root.pwFor = "" }
                    }
                }
            }
        }

        Item {
            width: root.width
            height: 48
            Button {
                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"
                size: "sm"
                text: tr.t("wifi.searchAgain")
                iconStart: root.g(0xF0450)
                onClicked: network.scan()
            }
        }
    }

    Text {
        visible: network.lastError !== ""
        width: root.width
        topPadding: 4
        text: network.lastError
        wrapMode: Text.Wrap
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    SettingRow {
        visible: network.hasWifi
        width: root.width
        icon: g(0xF0493)
        label: tr.t("nav.network.wifi.known")
        desc: tr.t("wifi.savedCount").arg(network.known.length)
        onClicked: root.navigate("network/wifi/known")
    }
}
