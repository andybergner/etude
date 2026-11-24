import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Automatisch sperren, Bildschirm aus, Energiesparmodus – komplett in Quickshell
// (statt hypridle). Nutzt das Wayland-Protokoll ext-idle-notify über IdleMonitor:
// Fenster, die Leerlauf verhindern (z. B. Videos), werden berücksichtigt.
//
// Außerdem:
//   - "loginctl lock-session" sperrt den Bildschirm (Signal Lock von logind)
//   - vor jedem Energiesparmodus wird gesperrt (auch Deckel zu / Startmenü),
//     dafür hält Idle eine kurze "delay"-Sperre bei systemd-logind
Item {
    id: root

    required property var settings        // Etude.Services/EtudeConfig
    signal lockRequested()

    // Netz- oder Akkubetrieb → passende Zeiten (Minuten, 0 = nie)
    readonly property bool onBattery: UPower.onBattery
    readonly property int lockMin:    onBattery ? settings.idleBatLock    : settings.idleAcLock
    readonly property int screenMin:  onBattery ? settings.idleBatScreen  : settings.idleAcScreen
    readonly property int suspendMin: onBattery ? settings.idleBatSuspend : settings.idleAcSuspend

    function dpms(on) {
        Hyprland.dispatch("hl.dsp.dpms({ action = \"" + (on ? "enable" : "disable") + "\" })")
    }

    // IdleMonitor übernimmt eine geänderte Zeit nicht zuverlässig (die Wayland-Benachrichtigung
    // wird mit der ersten Zeit angelegt). Darum werden die Monitore bei jeder Änderung neu
    // erzeugt – über Loader, die kurz aus- und wieder eingeschaltet werden.
    property bool monitorsOn: false
    function rebuild() { monitorsOn = false; rebuildTimer.restart() }
    Timer { id: rebuildTimer; interval: 300; onTriggered: { root.monitorsOn = true; root.logState() } }
    onLockMinChanged: rebuild()
    onScreenMinChanged: rebuild()
    onSuspendMinChanged: rebuild()

    function logState() {
        console.log("Etude idle: lock after", root.lockMin, "min, screen off after",
                    root.screenMin, "min, suspend after", root.suspendMin, "min")
    }

    // ---- Sperren ----
    Loader {
        id: lockMon
        active: root.monitorsOn && root.lockMin > 0
        sourceComponent: IdleMonitor {
            timeout: root.lockMin * 60
            respectInhibitors: true
            onIsIdleChanged: {
                console.log("Etude idle: lock", isIdle ? "→ now" : "(activity)")
                if (isIdle) root.lockRequested()
            }
        }
    }

    // ---- Bildschirm aus (bei Aktivität wieder an) ----
    Loader {
        id: screenMon
        active: root.monitorsOn && root.screenMin > 0
        sourceComponent: IdleMonitor {
            timeout: root.screenMin * 60
            respectInhibitors: true
            onIsIdleChanged: {
                console.log("Etude idle: screen", isIdle ? "off" : "on")
                root.dpms(!isIdle)
            }
        }
    }

    // ---- Energiesparmodus ----
    Loader {
        id: suspendMon
        active: root.monitorsOn && root.suspendMin > 0
        sourceComponent: IdleMonitor {
            timeout: root.suspendMin * 60
            respectInhibitors: true
            onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "suspend"])
        }
    }

    // Zum Prüfen:  qs -p $ETUDE_HOME/shell ipc call idle status
    IpcHandler {
        target: "idle"
        function status(): string {
            return "battery: " + root.onBattery
                 + " | lock: " + root.lockMin + " min (active " + !!lockMon.item
                 + ", idle " + (lockMon.item ? lockMon.item.isIdle : "-") + ")"
                 + " | screen: " + root.screenMin + " min (idle " + (screenMon.item ? screenMon.item.isIdle : "-") + ")"
                 + " | suspend: " + root.suspendMin + " min"
        }
    }

    // ---- logind beobachten: Lock-Signal und PrepareForSleep ----
    Process {
        id: logindWatch
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: (line) => {
                if (/\.Lock \(\)/.test(line)) {
                    root.lockRequested()
                } else if (/PrepareForSleep \(true/.test(line)) {
                    if (root.settings.lockOnSuspend) root.lockRequested()
                    releaseTimer.restart()          // kurz Zeit zum Sperren geben
                } else if (/PrepareForSleep \(false/.test(line)) {
                    root.dpms(true)                 // nach dem Aufwachen Bildschirm an
                    inhibitor.running = root.settings.lockOnSuspend
                }
            }
        }
        // falls gdbus beendet wird (z. B. dbus-Neustart): neu starten
        onExited: restartWatch.start()
    }
    Timer { id: restartWatch; interval: 2000; onTriggered: logindWatch.running = true }

    // Hält den Energiesparmodus kurz auf, bis der Sperrbildschirm steht
    Process {
        id: inhibitor
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Etude",
                  "--why=Lock screen", "sleep", "infinity"]
    }
    Component.onCompleted: {
        inhibitor.running = root.settings.lockOnSuspend
        // kurz warten, bis die Einstellungen geladen sind, dann die Monitore anlegen
        rebuild()
    }
    Connections {
        target: root.settings
        function onLockOnSuspendChanged() { inhibitor.running = root.settings.lockOnSuspend }
    }
    Timer {
        id: releaseTimer
        interval: 600
        onTriggered: inhibitor.running = false        // jetzt darf das System schlafen
    }
}
