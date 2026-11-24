import QtQuick
import Quickshell
import Quickshell.Io

// Energiemodus über power-profiles-daemon (powerprofilesctl)
Item {
    id: root

    property bool available: false
    property string profile: "balanced"   // "power-saver" | "balanced" | "performance"
    readonly property bool saver: profile === "power-saver"

    function set(p) {
        Quickshell.execDetached(["powerprofilesctl", "set", p])
        profile = p
    }
    function toggle() { set(saver ? "balanced" : "power-saver") }
    function refresh() { proc.running = true }

    Process {
        id: proc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: { root.available = true; root.profile = this.text.trim() || "balanced" }
        }
        onExited: (code) => { if (code !== 0) root.available = false }
    }
    Component.onCompleted: refresh()
}
