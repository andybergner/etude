import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet › Proxy (Aufbau wie Windows 11):
//   Automatische Proxyeinrichtung: automatisch erkennen / Setupskript (PAC)
//   Manuelle Proxyeinrichtung: Proxyserver mit Adresse, Port und Ausnahmen
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var hypr          // HyprSettings.qml (speichert und setzt Umgebung)
    readonly property var p: hypr.proxy

    spacing: 4

    function g(cp) { return String.fromCodePoint(cp) }
    function apply(changes) {
        const n = Object.assign({}, root.p, changes)
        root.hypr.setProxy(n)
    }

    // ===== Automatisch =====
    SectionTitle { text: tr.t("proxy.automaticProxySetup"); topPadding: 0 }

    SettingRow {
        width: root.width
        chevron: false
        icon: g(0xF059F)
        label: tr.t("proxy.automaticallyDetectSettings")
        desc: tr.t("proxy.findTheProxyOnThe")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.p.mode === "auto" && !root.p.pac
            onToggled: root.apply({ mode: root.p.mode === "auto" && !root.p.pac ? "none" : "auto", pac: "" })
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: g(0xF0219)
        label: tr.t("proxy.useSetupScript")
        desc: root.p.mode === "auto" && root.p.pac ? tr.t("proxy.onValue").arg(root.p.pac) : I18n.t("common.off")
        Button {
            id: pacBtn
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("proxy.setUp")
            onClicked: { pacUrl.text = root.p.pac || ""; pacOn.checked = root.p.mode === "auto" && !!root.p.pac; pacPop.open() }
        }
    }

    Dialog {
        id: pacPop
        title: tr.t("proxy.editSetupScript")
        description: tr.t("proxy.theProxyConfigurationComesFrom")
        Row {
            spacing: 12
            Switch { id: pacOn; anchors.verticalCenter: parent.verticalCenter; onToggled: checked = !checked }
            Label { anchors.verticalCenter: parent.verticalCenter; text: tr.t("proxy.useSetupScript") }
        }
        Field {
            width: parent.width
            label: tr.t("proxy.scriptAddress")
            error: pacOn.checked && pacUrl.text !== "" && !/^https?:\/\/\S+$/.test(pacUrl.text.trim()) ? tr.t("proxy.theAddressMustStartWith") : ""
            Input { id: pacUrl; width: parent.width; placeholder: "http://wpad.firma.local/proxy.pac"; enabled: pacOn.checked }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: I18n.t("common.save")
                enabled: !pacOn.checked || /^https?:\/\/\S+$/.test(pacUrl.text.trim())
                onClicked: {
                    root.apply(pacOn.checked ? { mode: "auto", pac: pacUrl.text.trim() } : { mode: "none", pac: "" })
                    pacPop.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: pacPop.close() }
        }
    }

    // ===== Manuell =====
    SectionTitle { text: tr.t("proxy.manualProxySetup") }

    SettingRow {
        width: root.width
        chevron: false
        icon: g(0xF0493)
        label: tr.t("proxy.useAProxyServer")
        desc: root.p.mode === "manual" && root.p.host ? tr.t("proxy.onValue").arg(root.p.host + ":" + root.p.port) : I18n.t("common.off")
        Button {
            id: manBtn
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("proxy.setUp")
            onClicked: {
                manOn.checked = root.p.mode === "manual"
                host.text = root.p.host || ""
                port.text = root.p.port || ""
                noProxy.text = root.p.noProxy || "localhost,127.0.0.1,::1"
                manPop.open()
            }
        }
    }

    Dialog {
        id: manPop
        title: tr.t("proxy.editProxyServer")
        Row {
            spacing: 12
            Switch { id: manOn; anchors.verticalCenter: parent.verticalCenter; onToggled: checked = !checked }
            Label { anchors.verticalCenter: parent.verticalCenter; text: tr.t("proxy.useAProxyServer") }
        }
        Row {
            width: parent.width
            spacing: 8
            Field {
                width: parent.width - 96 - 8
                label: tr.t("proxy.proxyIpAddress")
                Input { id: host; width: parent.width; placeholder: "proxy.firma.local"; enabled: manOn.checked }
            }
            Field {
                width: 96
                label: tr.t("proxy.port")
                Input { id: port; width: parent.width; placeholder: "3128"; enabled: manOn.checked }
            }
        }
        Field {
            width: parent.width
            label: tr.t("proxy.exceptions")
            hint: tr.t("proxy.separateWithCommasCompanyLocal")
            Input { id: noProxy; width: parent.width; placeholder: "localhost,127.0.0.1,.firma.local"; enabled: manOn.checked }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: I18n.t("common.save")
                enabled: !manOn.checked || (/^[A-Za-z0-9.\-_]+$/.test(host.text.trim()) && /^\d{1,5}$/.test(port.text.trim()))
                onClicked: {
                    root.apply(manOn.checked
                        ? { mode: "manual", host: host.text.trim(), port: port.text.trim(), noProxy: noProxy.text.trim() }
                        : { mode: "none" })
                    manPop.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: manPop.close() }
        }
    }

    Text {
        width: root.width
        topPadding: 12
        text: tr.t("proxy.appliesToProgramsStartedAfterwards")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
