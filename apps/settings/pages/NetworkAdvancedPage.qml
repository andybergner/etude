import QtQuick
import Etude.Ui
import "../components"

// Netzwerk & Internet › Erweiterte Netzwerkeinstellungen: Netzwerkadapter
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var network        // Etude.Services/Network

    spacing: 4

    Component.onCompleted: network.loadAdvanced()

    function stateText(s) {
        if (s.startsWith("connected")) return tr.t("adapters.connected")
        if (s === "disconnected") return tr.t("adapters.disconnected")
        if (s === "unavailable") return tr.t("adapters.unavailableNoCable")
        if (s === "unmanaged") return tr.t("adapters.unmanaged")
        if (s.startsWith("connecting")) return tr.t("adapters.connecting")
        return s
    }

    SectionTitle { text: tr.t("adapters.networkAdapters"); topPadding: 0 }

    Repeater {
        model: network.adapters
        delegate: SettingRow {
            required property var modelData
            readonly property bool on: modelData.state.startsWith("connected")
            width: root.width
            chevron: false
            icon: String.fromCodePoint(modelData.type === "wifi" ? 0xF05A9 : 0xF0200)
            label: (modelData.type === "wifi" ? "WLAN" : tr.t("adapters.ethernet")) + " (" + modelData.device + ")"
            desc: root.stateText(modelData.state) + (modelData.connection && modelData.connection !== "--" ? " · " + modelData.connection : "")
            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.state !== "unmanaged" && modelData.state !== "unavailable"
                variant: "outline"
                size: "sm"
                text: parent.parent.on ? tr.t("adapters.disable") : tr.t("adapters.enable")
                enabled: !root.network.busy
                onClicked: root.network.adapterToggle(modelData.device, !parent.parent.on)
            }
        }
    }

    SettingRow {
        visible: network.adapters.length === 0
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0A8E)
        label: tr.t("adapters.noNetworkAdaptersFound")
        desc: tr.t("adapters.isNetworkmanagerRunningSystemctlStatus")
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
