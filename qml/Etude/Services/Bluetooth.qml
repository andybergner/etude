import QtQuick
import Quickshell.Bluetooth

// Bluetooth über BlueZ (in der VM meist nicht vorhanden)
Item {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool enabled: present && adapter.enabled
    readonly property string device: {
        if (!present || !adapter.devices) return ""
        const d = adapter.devices.values.find(x => x.connected)
        return d ? (d.name || d.deviceName || "") : ""
    }
    readonly property bool scanning: present && adapter.discovering
    readonly property var devices: {
        if (!present || !adapter.devices) return []
        return adapter.devices.values.map(d => ({
            address: d.address,
            name: d.name || d.deviceName || d.address,
            icon: d.icon || "",
            connected: d.connected,
            paired: d.paired,
            pairing: d.pairing || false,
            battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1
        }))
    }

    function toggle() { if (present) adapter.enabled = !adapter.enabled }
    function setScanning(on) { if (present && adapter.enabled) adapter.discovering = on }
    function forget(address) {
        if (!present) return
        const d = adapter.devices.values.find(x => x.address === address)
        if (d) d.forget()
    }
    function deviceAction(address) {
        if (!present) return
        const d = adapter.devices.values.find(x => x.address === address)
        if (!d) return
        if (!d.paired) { d.trusted = true; d.pair() }    // neues Gerät koppeln
        else if (d.connected) d.disconnect()
        else d.connect()
    }
}
