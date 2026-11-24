import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Etude.Services
import Etude.Lock

// Sperrbildschirm über ext-session-lock: solange gesperrt, kommt nichts anderes
// an Bildschirm und Tastatur – auch nicht, wenn die Shell abstürzt.
//
// Sperren:  qs -p $ETUDE_HOME/shell ipc call lock lock
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/etude"

    property string wallpaper: ""            // aus den Einstellungen ("" = Farbton)
    property color tint: "#18181b"

    function lock() { sessionLock.locked = true }

    // Netzwerk und Akku für die Symbole unten rechts
    Network { id: net }
    Battery { id: bat }
    readonly property string netIcon: StatusIcons.network(net.kind, net.signal)

    // Voller Name aus /etc/passwd (wie in den Einstellungen)
    property string realName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.realName = this.text.trim() }
    }

    function power(action) {
        if (action === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
        else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (action === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
    }

    LockContext {
        id: ctx
        onUnlocked: sessionLock.locked = false
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    WlSessionLock {
        id: sessionLock
        onLockedChanged: if (locked) ctx.reset()

        // eine Fläche pro Monitor
        WlSessionLockSurface {
            color: "black"
            LockSurface {
                anchors.fill: parent
                context: ctx
                now: clock.date
                // Hintergrund: ~/.config/etude/wallpaper (Bild oder Link auf ein Bild)
                wallpaper: root.wallpaper ? "file://" + root.wallpaper : ""
                tint: root.tint
                // Benutzerbild: ~/.face (Standard unter Linux)
                avatar: "file://" + root.home + "/.face"
                userName: root.realName || Quickshell.env("USER") || ""
                networkIcon: root.netIcon
                network: net                          // Klick aufs Symbol: Netzwerk-Menü
                networkKind: net.kind
                networkName: net.ssid
                batteryText: bat.present ? bat.level + " %" : ""
                batteryIcon: bat.present ? StatusIcons.battery(bat.level, bat.charging) : ""
                onPowerAction: (a) => root.power(a)
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function isLocked(): bool { return sessionLock.locked }
    }
}
