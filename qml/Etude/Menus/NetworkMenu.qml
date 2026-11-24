import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Netzwerk-Menü der Leiste (Aufbau wie Windows 11):
//   Kopf "WLAN" mit Schalter (nur mit WLAN-Adapter)
//   Kabelverbindung (falls verbunden)
//   Verbundenes WLAN oben, aufgeklappt mit "Eigenschaften" und "Trennen"
//   Andere Netze: Klick klappt auf → "Verbinden", bei Bedarf Netzwerkschlüssel
//   Fuß: Netzwerk- und Interneteinstellungen
MenuPage {
    id: root
    property Translations tr: Translations { domain: "menus" }   // Texte dieses Moduls

    required property var network        // Etude.Services/Network

    property string expandedSsid: ""     // aufgeklappter Eintrag
    property string keyFor: ""           // für dieses Netz wird der Schlüssel abgefragt

    signal openSettings(string page)
    property bool showSettings: true     // Anmeldebildschirm: keine Links in die Einstellungen

    title: tr.t(network.hasWifi ? "menus.wifi" : "menus.network")
    hasSwitch: network.hasWifi
    switchOn: network.wifiEnabled
    footerText: showSettings ? tr.t("menus.networkSettings") : ""
    onSwitchToggled: network.setWifi(!network.wifiEnabled)
    onFooterClicked: root.openSettings("network")

    Component.onCompleted: { network.refresh(); if (network.hasWifi) network.scan() }

    function g(cp) { return String.fromCodePoint(cp) }
    function icon(n) {
        const lvl = n.signal > 75 ? 3 : n.signal > 50 ? 2 : n.signal > 25 ? 1 : 0
        return n.secure ? g([0xF0921, 0xF0924, 0xF0927, 0xF092A][lvl]) : g([0xF091F, 0xF0922, 0xF0925, 0xF0928][lvl])
    }
    // verbundenes Netz zuerst, dann nach Signal
    readonly property var sorted: network.networks.slice().sort((a, b) => (b.active - a.active) || (b.signal - a.signal))

    function connectTo(n) {
        root.network.lastError = ""
        if (n.secure && !n.known) { root.keyFor = n.ssid; return }      // erst Schlüssel abfragen
        root.network.connect(n.ssid, "")
        root.expandedSsid = ""
    }

    Column {
        width: parent.width
        spacing: 2

        // ===== Kabel =====
        ListRow {
            visible: root.network.kind === "ethernet"
            width: parent.width
            icon: root.g(0xF0200)
            title: root.network.info.name || root.tr.t("menus.ethernet")
            subtitle: root.network.info.ip ? root.tr.t("menus.connectedIp").arg(root.network.info.ip.split("/")[0]) : root.tr.t("menus.connected")
            active: true
            expanded: true
            Row {
                width: parent.width
                layoutDirection: Qt.RightToLeft
                Button { visible: root.showSettings; text: root.tr.t("menus.properties"); size: "sm"; variant: "ghost"; onClicked: root.openSettings("ethernet") }
            }
        }

        // ===== Kein WLAN-Adapter / WLAN aus =====
        Text {
            visible: !root.network.hasWifi && root.network.kind !== "ethernet"
            width: parent.width; padding: 10
            text: root.tr.t("menus.noAdapter")
            wrapMode: Text.WordWrap
            color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
        }
        Text {
            visible: root.network.hasWifi && !root.network.wifiEnabled
            width: parent.width; padding: 10
            text: root.tr.t("menus.wifiOff")
            color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
        }
        Text {
            visible: root.network.hasWifi && root.network.wifiEnabled && root.network.networks.length === 0
            width: parent.width; padding: 10
            text: root.tr.t("menus.searchingNetworks")
            color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
        }

        // ===== WLANs =====
        Repeater {
            model: root.network.hasWifi && root.network.wifiEnabled ? root.sorted : []
            delegate: ListRow {
                id: row
                required property var modelData
                readonly property bool isActive: modelData.active
                readonly property bool asking: root.keyFor === modelData.ssid
                width: parent.width
                icon: root.icon(modelData)
                title: modelData.ssid
                subtitle: root.network.connecting === modelData.ssid ? root.tr.t("menus.connecting")
                        : isActive ? root.tr.t(modelData.secure ? "menus.connectedSecured" : "menus.connected")
                        : root.tr.t(modelData.secure ? "menus.secured" : "menus.open")
                active: isActive
                // verbundenes Netz ist immer aufgeklappt (wie Windows)
                expanded: isActive || root.expandedSsid === modelData.ssid
                onClicked: {
                    if (isActive) return
                    root.keyFor = ""
                    root.expandedSsid = root.expandedSsid === modelData.ssid ? "" : modelData.ssid
                }

                // Verbunden: Eigenschaften | Trennen
                Row {
                    visible: row.isActive
                    width: parent.width
                    spacing: 8
                    layoutDirection: Qt.RightToLeft
                    Button { text: root.tr.t("menus.disconnect"); size: "sm"; variant: "outline"; onClicked: root.network.disconnect(row.modelData.ssid) }
                    Button { visible: root.showSettings; text: root.tr.t("menus.properties"); size: "sm"; variant: "ghost"; onClicked: root.openSettings("wifi") }
                }

                // Nicht verbunden: Verbinden
                Row {
                    visible: !row.isActive && !row.asking
                    width: parent.width
                    layoutDirection: Qt.RightToLeft
                    Button {
                        text: root.tr.t("menus.connect")
                        size: "sm"
                        enabled: root.network.connecting === ""
                        onClicked: root.connectTo(row.modelData)
                    }
                }

                // Netzwerkschlüssel abfragen
                Text {
                    visible: row.asking
                    width: parent.width
                    text: root.tr.t("menus.enterKey")
                    color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 12
                }
                Input {
                    id: pw
                    visible: row.asking
                    width: parent.width
                    placeholder: root.tr.t("menus.networkKey")
                    echoMode: TextInput.Password
                    onAccepted: nextBtn.clicked()
                    onEscapePressed: root.keyFor = ""
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                }
                Row {
                    visible: row.asking
                    width: parent.width
                    spacing: 8
                    layoutDirection: Qt.RightToLeft
                    Button {
                        id: nextBtn
                        text: I18n.t("common.next")
                        size: "sm"
                        enabled: pw.text.length >= 8
                        onClicked: { root.network.connect(row.modelData.ssid, pw.text); root.keyFor = ""; root.expandedSsid = "" }
                    }
                    Button { text: I18n.t("common.cancel"); size: "sm"; variant: "ghost"; onClicked: root.keyFor = "" }
                }

                Text {
                    visible: root.network.lastError !== "" && !row.isActive
                    width: parent.width
                    text: root.network.lastError
                    wrapMode: Text.WordWrap
                    color: Theme.destructive; font.family: Theme.fontSans; font.pixelSize: 11
                }
            }
        }
    }
}
