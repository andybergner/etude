import QtQuick
import Quickshell.Services.UPower

// Akku über UPower (in der VM: kein Akku -> wird ausgeblendet)
Item {
    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery
    // je nach Quickshell-Version 0-1 oder 0-100
    readonly property int level: !present ? 0
                               : Math.round(device.percentage <= 1 ? device.percentage * 100 : device.percentage)
    // Restzeit in Sekunden: bis leer (entladen) bzw. bis voll (laden)
    readonly property int secondsLeft: !present ? 0 : Math.round(charging ? (device.timeToFull || 0) : (device.timeToEmpty || 0))
    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging
                                              || device.state === UPowerDeviceState.FullyCharged)
}
