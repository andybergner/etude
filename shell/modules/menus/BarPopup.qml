// Ein Fenster für alle Menüs der Leiste (Netzwerk, Bluetooth, Lautsprecher, Akku).
// open("network", button) zeigt das passende Menü rechtsbündig über dem Button.
// Klick daneben oder Esc schließt.
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui
import Etude.Menus                         // Netzwerk-, Bluetooth-, Ton- und Akku-Menü (auch für den Anmeldebildschirm)
import "../bar/Place.js" as Place

PanelWindow {
    id: win

    property real barHeight: 48
    property bool atBottom: true

    // Dienste (kommen aus Bar.qml)
    property var network
    property var audio
    property var battery
    property var bluetooth
    property var brightness
    property var power
    property var media

    property string current: ""          // "network" | "bluetooth" | "sound" | "battery"
    property real anchorRight: -1
    property real anchorLeft: -1

    signal openSettings(string page)

    function toggle(name, anchorItem) {
        if (visible && current === name) { close(); return }
        open(name, anchorItem)
    }
    function open(name, anchorItem) {
        current = name
        anchorRight = anchorItem ? anchorItem.mapToItem(null, anchorItem.width, 0).x : -1
        anchorLeft = anchorItem ? anchorItem.mapToItem(null, 0, 0).x : -1
        if (name === "network" && network) { network.refresh(); network.scan() }
        if (name === "bluetooth" && bluetooth) bluetooth.setScanning(true)
        if (name === "battery" && power) power.refresh()
        visible = true
    }
    function close() {
        if (bluetooth) bluetooth.setScanning(false)
        visible = false
        current = ""
    }

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Die Leiste bleibt klickbar: Klicks dort gehen an die Leiste, nicht an die Klickfläche zum Schließen.
    // So öffnet ein Klick auf einen anderen Button sofort dessen Menü.
    mask: Region {
        x: 0
        y: win.atBottom ? 0 : win.barHeight
        width: win.width
        height: Math.max(0, win.height - win.barHeight)
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "etude-menu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: win.close() }

    FocusRoot {                              // Tastatur wie bei Windows (Pfeile, Enter, Fokus-Ring)
        anchors.fill: parent
    FocusScope {
        id: holder
        focus: true
        width: loader.item ? loader.item.width : 0
        height: loader.item ? loader.item.height : 0
        // je nach Lage des Buttons: links, mittig oder am rechten Rand
        x: Place.x(win.anchorLeft, win.anchorRight, width, win.width)
        y: win.atBottom ? win.height - win.barHeight - height - 8 : win.barHeight + 8
        Keys.onEscapePressed: win.close()

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // Klicks nicht durchreichen

        Loader {
            id: loader
            active: win.visible
            sourceComponent: win.current === "network" ? networkMenu
                           : win.current === "bluetooth" ? bluetoothMenu
                           : win.current === "sound" ? soundMenu
                           : win.current === "battery" ? batteryMenu : null
            onLoaded: holder.forceActiveFocus()
        }
    }

    Component {
        id: networkMenu
        NetworkMenu {
            network: win.network
            onOpenSettings: (page) => { win.close(); win.openSettings(page) }
        }
    }
    Component {
        id: bluetoothMenu
        BluetoothMenu {
            btOn: win.bluetooth.enabled
            scanning: win.bluetooth.scanning
            devices: win.bluetooth.devices
            onToggleBluetooth: win.bluetooth.toggle()
            onDeviceClicked: (a) => win.bluetooth.deviceAction(a)
            onScan: (on) => win.bluetooth.setScanning(on)
            onOpenSettings: { win.close(); win.openSettings("bluetooth") }
        }
    }
    Component {
        id: soundMenu
        SoundMenu {
            volume: win.audio.volume
            muted: win.audio.muted
            sinks: win.audio.sinks
            hasMedia: win.media.active
            mediaApp: win.media.app
            mediaTitle: win.media.title
            mediaArtist: win.media.artist
            mediaPlaying: win.media.playing
            onSetVolume: (v) => win.audio.set(v)
            onToggleMute: win.audio.toggleMute()
            onSelectSink: (id) => win.audio.select(id)
            onMediaPrevious: win.media.previous()
            onMediaPlayPause: win.media.playPause()
            onMediaNext: win.media.next()
            onOpenSettings: { win.close(); win.openSettings("sound") }
        }
    }
    Component {
        id: batteryMenu
        BatteryMenu {
            level: win.battery.level
            charging: win.battery.charging
            secondsLeft: win.battery.secondsLeft
            profile: win.power.profile
            profilesAvailable: win.power.available
            hasBrightness: win.brightness.present
            brightness: win.brightness.value
            onSetProfile: (p) => win.power.set(p)
            onSetBrightness: (v) => win.brightness.set(v)
            onOpenSettings: { win.close(); win.openSettings("power") }
        }
    }
    }
}
