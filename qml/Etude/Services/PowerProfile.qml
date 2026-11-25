import QtQuick
import Quickshell
import Quickshell.Io

// Energiemodus über power-profiles-daemon – direkt per D-Bus (busctl), ohne powerprofilesctl
// (das braucht python-gobject und meldet sonst fälschlich „nicht installiert“).
//   status "missing"  Paket fehlt
//          "stopped"  installiert, Dienst läuft nicht → enable() startet ihn (Admin-Abfrage)
//          "running"  alles gut
Item {
    id: root

    property string status: "missing"
    readonly property bool available: status === "running"
    readonly property bool installed: status !== "missing"
    property string profile: "balanced"                    // "power-saver" | "balanced" | "performance"
    property var profiles: ["power-saver", "balanced", "performance"]   // was diese Hardware kann
    readonly property bool saver: profile === "power-saver"
    property bool busy: false                              // enable() läuft

    // Dienstname: neu (seit 0.20) org.freedesktop.UPower.PowerProfiles, alt net.hadess.PowerProfiles
    property string bus: "org.freedesktop.UPower.PowerProfiles"
    property string objectPath: "/org/freedesktop/UPower/PowerProfiles"

    function set(p) {
        if (!available || profiles.indexOf(p) < 0) return
        profile = p
        Quickshell.execDetached(["busctl", "--system", "set-property", bus, objectPath, bus, "ActiveProfile", "s", p])
        refreshSoon.restart()
    }
    function toggle() { set(saver ? "balanced" : "power-saver") }
    function refresh() { if (!proc.running) proc.running = true }
    function enable() {
        if (busy) return
        busy = true
        enableProc.running = true
    }

    Process {
        id: proc
        command: ["sh", "-c",
            "for n in 'org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles' " +
            "'net.hadess.PowerProfiles /net/hadess/PowerProfiles'; do set -- $n; " +
            "a=$(busctl --json=short --system get-property \"$1\" \"$2\" \"$1\" ActiveProfile 2>/dev/null) || continue; " +
            "p=$(busctl --json=short --system get-property \"$1\" \"$2\" \"$1\" Profiles 2>/dev/null); " +
            "printf 'RUNNING %s %s\\n%s\\n%s\\n' \"$1\" \"$2\" \"$a\" \"$p\"; exit 0; done; " +
            "if [ -e /usr/lib/systemd/system/power-profiles-daemon.service ]; then echo STOPPED; else echo MISSING; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const head = (lines[0] || "").split(" ")
                if (head[0] !== "RUNNING") {
                    root.status = head[0] === "STOPPED" ? "stopped" : "missing"
                    return
                }
                root.bus = head[1]
                root.objectPath = head[2]
                try { root.profile = JSON.parse(lines[1]).data || "balanced" } catch (e) {}
                try {
                    const list = (JSON.parse(lines[2]).data || []).map(d => d.Profile && d.Profile.data).filter(Boolean)
                    if (list.length) root.profiles = list
                } catch (e) {}
                root.status = "running"
            }
        }
    }

    // Dienst einschalten und starten (pkexec fragt nach dem Admin-Kennwort)
    Process {
        id: enableProc
        command: ["pkexec", "systemctl", "enable", "--now", "power-profiles-daemon.service"]
        onExited: { root.busy = false; refreshSoon.restart() }
    }

    Timer { id: refreshSoon; interval: 600; onTriggered: root.refresh() }
    // Auch Änderungen von außen (Leiste, andere Programme) mitbekommen
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
