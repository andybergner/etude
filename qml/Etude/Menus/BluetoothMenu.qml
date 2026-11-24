import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Bluetooth-Menü: gekoppelte Geräte verbinden/trennen, neue Geräte suchen und koppeln
MenuPage {
    id: root
    property Translations tr: Translations { domain: "menus" }   // Texte dieses Moduls

    property bool btOn: true
    property bool scanning: false
    property var devices: []            // [{ address, name, icon, connected, paired }]

    signal toggleBluetooth()
    signal deviceClicked(string address)
    signal scan(bool on)
    signal openSettings()

    title: tr.t("menus.bluetooth")
    hasSwitch: true
    switchOn: btOn
    footerText: tr.t("menus.bluetoothSettings")
    onSwitchToggled: root.toggleBluetooth()
    onFooterClicked: root.openSettings()

    readonly property var paired: devices.filter(d => d.paired)
    readonly property var others: devices.filter(d => !d.paired)

    function g(cp) { return String.fromCodePoint(cp) }
    function icon(name) {
        name = (name || "").toLowerCase()
        if (name.indexOf("headset") >= 0) return g(0xF02CE)
        if (name.indexOf("audio") >= 0 || name.indexOf("head") >= 0) return g(0xF02CB)
        if (name.indexOf("keyboard") >= 0) return g(0xF030C)
        if (name.indexOf("mouse") >= 0) return g(0xF037D)
        if (name.indexOf("phone") >= 0) return g(0xF011C)
        if (name.indexOf("computer") >= 0) return g(0xF0322)
        if (name.indexOf("game") >= 0) return g(0xF0297)
        return g(0xF00AF)
    }

    Column {
        width: parent.width
        spacing: 2

        Text {
            visible: !root.btOn
            width: parent.width; padding: 10
            text: root.tr.t("menus.bluetoothOff")
            color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
        }

        SectionLabel { visible: root.btOn && root.paired.length > 0; text: root.tr.t("menus.myDevices") }
        Repeater {
            model: root.btOn ? root.paired : []
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: root.icon(modelData.icon)
                title: modelData.name
                subtitle: root.tr.t(modelData.connected ? "menus.connected" : "menus.paired")
                trailing: modelData.connected ? root.g(0xF012C) : ""
                active: modelData.connected
                onClicked: root.deviceClicked(modelData.address)
            }
        }

        RowLayout {
            visible: root.btOn
            width: parent.width
            SectionLabel { Layout.fillWidth: true; text: root.tr.t("menus.nearbyDevices") }
            Button { size: "sm"; variant: "ghost"; text: root.tr.t(root.scanning ? "menus.scanning" : "menus.scan"); onClicked: root.scan(!root.scanning) }
        }
        Text {
            visible: root.btOn && root.others.length === 0
            width: parent.width; leftPadding: 10; bottomPadding: 8
            text: root.tr.t(root.scanning ? "menus.searchingDevices" : "menus.noNewDevices")
            color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
        }
        Repeater {
            model: root.btOn ? root.others : []
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: root.icon(modelData.icon)
                title: modelData.name
                subtitle: root.tr.t("menus.clickToPair")
                onClicked: root.deviceClicked(modelData.address)
            }
        }
    }
}
