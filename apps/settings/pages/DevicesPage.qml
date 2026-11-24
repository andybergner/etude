import QtQuick
import Etude.Ui
import "../components"
import "../components/DeviceIcons.js" as DeviceIcons

// Bluetooth & Geräte › Geräte: gekoppelte Geräte verbinden/trennen/entfernen,
// neue Geräte suchen und koppeln
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var bluetooth     // Etude.Services/Bluetooth

    spacing: 4

    // Suche beim Verlassen der Seite wieder beenden
    Component.onDestruction: if (bluetooth.scanning) bluetooth.setScanning(false)

    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var paired: bluetooth.devices.filter(d => d.paired)
    readonly property var others: bluetooth.devices.filter(d => !d.paired && d.name !== d.address)

    SettingRow {
        visible: !root.bluetooth.present || !root.bluetooth.enabled
        width: root.width
        chevron: false
        icon: g(0xF00B2)
        label: !root.bluetooth.present ? tr.t("devices.noBluetoothAdapterFound") : tr.t("devices.bluetoothIsTurnedOff")
        Switch {
            visible: root.bluetooth.present
            anchors.verticalCenter: parent.verticalCenter
            checked: root.bluetooth.enabled
            onToggled: root.bluetooth.toggle()
        }
    }

    // ===== Gerät hinzufügen =====
    SettingRow {
        visible: root.bluetooth.enabled
        width: root.width
        chevron: false
        icon: g(0xF0415)
        label: tr.t("devices.addDevice")
        desc: root.bluetooth.scanning ? tr.t("devices.searchingForNearbyDevicesPut")
                                      : tr.t("devices.headphonesMouseKeyboardSpeakers")
        Button {
            anchors.verticalCenter: parent.verticalCenter
            variant: root.bluetooth.scanning ? "outline" : "default"
            size: "sm"
            text: root.bluetooth.scanning ? tr.t("devices.stopSearching") : tr.t("devices.search")
            onClicked: root.bluetooth.setScanning(!root.bluetooth.scanning)
        }
    }

    // ===== Neue Geräte (während der Suche) =====
    SectionTitle { visible: root.bluetooth.enabled && root.bluetooth.scanning; text: tr.t("devices.devicesFound") }
    Repeater {
        model: root.bluetooth.enabled && root.bluetooth.scanning ? root.others : []
        delegate: SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: DeviceIcons.icon(modelData.icon || modelData.name)
            label: modelData.name
            desc: modelData.pairing ? tr.t("devices.pairing") : modelData.address
            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: "sm"
                text: tr.t("devices.pair")
                enabled: !modelData.pairing
                onClicked: root.bluetooth.deviceAction(modelData.address)
            }
        }
    }
    Text {
        visible: root.bluetooth.enabled && root.bluetooth.scanning && root.others.length === 0
        width: root.width
        padding: 8
        text: tr.t("devices.noDevicesFoundYet")
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    // ===== Meine Geräte =====
    SectionTitle { visible: root.bluetooth.enabled; text: tr.t("devices.myDevices") }
    Repeater {
        model: root.bluetooth.enabled ? root.paired : []
        delegate: SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: DeviceIcons.icon(modelData.icon || modelData.name)
            label: modelData.name
            desc: tr.t(modelData.connected ? "devices.connected" : "devices.paired")
                  + (modelData.battery >= 0 ? " · " + tr.t("devices.battery").arg(modelData.battery) : "")
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "outline"
                size: "sm"
                text: modelData.connected ? tr.t("devices.disconnect") : tr.t("devices.connect")
                onClicked: root.bluetooth.deviceAction(modelData.address)
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"
                size: "sm"
                text: I18n.t("common.remove")
                onClicked: root.bluetooth.forget(modelData.address)
            }
        }
    }
    Text {
        visible: root.bluetooth.enabled && root.paired.length === 0
        width: root.width
        padding: 8
        text: tr.t("devices.noDevicesPairedYet")
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
