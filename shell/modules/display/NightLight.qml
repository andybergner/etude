import QtQuick
import Quickshell
import Quickshell.Io

// Nachtlicht: wärmere Farben über hyprsunset (läuft, solange es eingeschaltet ist)
Item {
    id: root

    required property var settings        // EtudeConfig (nightLight, nightTemp)

    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(root.settings.nightTemp)]
        running: false
        onExited: (code) => { if (code === 127) console.warn("Etude night light: hyprsunset is not installed") }
    }

    function apply() {
        sunset.running = false
        if (!root.settings.nightLight) return
        sunset.command = ["hyprsunset", "-t", String(root.settings.nightTemp)]
        startLater.restart()
    }
    Timer { id: startLater; interval: 200; onTriggered: sunset.running = true }
    // Slider schickt viele Werte – erst nach kurzer Pause neu starten
    Timer { id: debounce; interval: 300; onTriggered: root.apply() }

    Connections {
        target: root.settings
        function onNightLightChanged() { root.apply() }
        function onNightTempChanged() { debounce.restart() }
    }
    Component.onCompleted: debounce.restart()
}
