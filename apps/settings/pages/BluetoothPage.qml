import QtQuick
import Etude.Ui
import "../components"
import "../components/DeviceIcons.js" as DeviceIcons
import "../Nav.js" as Nav

// Bluetooth & Geräte (Aufbau wie Windows 11):
//   Bluetooth-Schalter, Kacheln der gekoppelten Geräte + tr.t("devices.addDevice"),
//   darunter Geräte, Maus, Touchpad, Tastatur
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var bluetooth     // Etude.Services/Bluetooth
    required property var hypr          // HyprSettings (hasTouchpad)
    signal navigate(string path)

    spacing: 4

    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var paired: bluetooth.devices.filter(d => d.paired)

    // ===== Bluetooth =====
    SettingRow {
        width: root.width
        chevron: false
        icon: g(root.bluetooth.enabled ? 0xF00AF : 0xF00B2)
        label: tr.t("bluetooth.bluetooth")
        desc: !root.bluetooth.present ? tr.t("devices.noBluetoothAdapterFound")
            : !root.bluetooth.enabled ? I18n.t("common.off")
            : root.bluetooth.device ? tr.t("network.connectedTo").arg(root.bluetooth.device) : I18n.t("common.on")
        Switch {
            visible: root.bluetooth.present
            anchors.verticalCenter: parent.verticalCenter
            checked: root.bluetooth.enabled
            onToggled: root.bluetooth.toggle()
        }
    }

    // ===== Kacheln: gekoppelte Geräte + Gerät hinzufügen =====
    Flow {
        visible: root.bluetooth.present && root.bluetooth.enabled
        width: root.width
        spacing: 8
        topPadding: 8
        bottomPadding: 8

        Repeater {
            model: root.paired
            delegate: Rectangle {
                id: tile
                required property var modelData
                width: 200; height: 76
                radius: Theme.radiusMd
                color: Theme.card
                border.width: 1
                border.color: Theme.border
                HoverLayer { shown: tileMouse.containsMouse }
                Row {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DeviceIcons.icon(tile.modelData.icon || tile.modelData.name)
                        color: Theme.foreground
                        font.family: Theme.fontIcon
                        font.pixelSize: 22
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 130
                        Text {
                            width: parent.width
                            text: tile.modelData.name
                            elide: Text.ElideRight
                            color: Theme.foreground
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                        }
                        Text {
                            text: tr.t(tile.modelData.connected ? "devices.connected" : "devices.paired")
                                  + (tile.modelData.battery >= 0 ? " · " + tile.modelData.battery + " %" : "")
                            color: Theme.mutedForeground
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                        }
                    }
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigate("bluetooth/devices")
                }
            }
        }

        // Gerät hinzufügen
        Rectangle {
            width: 200; height: 76
            radius: Theme.radiusMd
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            HoverLayer { shown: addMouse.containsMouse }
            Row {
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.g(0xF0415); color: Theme.foreground; font.family: Theme.fontIcon; font.pixelSize: 18 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: tr.t("devices.addDevice"); color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 13 }
            }
            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.bluetooth.setScanning(true); root.navigate("bluetooth/devices") }
            }
        }
    }

    Item { width: 1; height: 4 }

    // ===== Unterseiten =====
    Repeater {
        model: Nav.pagesT(tr, "bluetooth").filter(p => p.id !== "touchpad" || root.hypr.hasTouchpad)
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate("bluetooth/" + modelData.id)
        }
    }
    SettingRow {
        width: root.width
        icon: g(0xF030C)
        label: tr.t("nav.time.keyboard")
        desc: tr.t("nav.time.keyboardDesc")
        onClicked: root.navigate("time/keyboard")
    }
}
