import QtQuick
import Quickshell
import Quickshell.Io

// Bildschirmhelligkeit über brightnessctl (in der VM: kein Backlight -> ausgeblendet)
Item {
    id: root

    property bool present: false
    property real value: 1.0          // 0..1

    function set(v) {
        value = v
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.max(1, Math.round(v * 100)) + "%"])
    }

    // neu einlesen (z. B. nach den Helligkeitstasten fürs OSD)
    function refresh() { proc.running = true }

    // "intel_backlight,backlight,512,50%,1024"
    Process {
        id: proc
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(",")
                root.present = f.length >= 5 && f[1] === "backlight"
                if (root.present) root.value = parseInt(f[2]) / parseInt(f[4])
            }
        }
        onExited: (code) => { if (code !== 0) root.present = false }
    }
    Component.onCompleted: proc.running = true
}
