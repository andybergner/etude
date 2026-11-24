import QtQuick
import Quickshell
import Quickshell.Io

// Der Anmeldebildschirm folgt automatisch deinem Aussehen: Hintergrund, Hell/Dunkel, Akzentfarbe.
// Ändert sich etwas (egal ob über die Einstellungen oder etude-config), schreibt die Shell es
// über `pkexec etude-greeter appearance` nach /etc/etude/greeter. Eine polkit-Regel erlaubt genau
// diesen Befehl für Mitglieder von "wheel" ohne Passwort – sonst wird nicht still synchronisiert.
Scope {
    id: root

    required property var config        // EtudeConfig

    property string program: "/usr/bin/etude-greeter"
    property bool allowed: false        // Paket installiert und Nutzer in "wheel"
    property var current: ({})          // /etc/etude/greeter/appearance.json

    readonly property var wanted: ({
        dark: config.dark,
        accent: config.accent || "",
        // Hintergrund wie der Sperrbildschirm (Personalisierung › Sperrbildschirm)
        wallpaperMode: config.lockActiveWallpaper ? "image" : "color",
        wallpaperColor: config.lockTint,
        source: config.lockActiveWallpaper || ""
    })
    function differs() {
        const c = current
        return c.dark !== wanted.dark || (c.accent || "") !== wanted.accent || c.wallpaperMode !== wanted.wallpaperMode
            || (c.wallpaperColor || "") !== wanted.wallpaperColor || (c.source || "") !== wanted.source
    }

    Process {
        running: true
        command: ["sh", "-c", "[ -x " + root.program + " ] && id -nG | tr ' ' '\\n' | grep -qx wheel"]
        onExited: (code) => { root.allowed = code === 0; syncTimer.restart() }
    }
    FileView {
        path: "/etc/etude/greeter/appearance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.current = JSON.parse(text()) || {} } catch (e) { root.current = {} } }
        onLoadFailed: root.current = ({})
    }

    onWantedChanged: syncTimer.restart()
    Timer {
        id: syncTimer
        interval: 2000                  // Änderungen sammeln (z. B. Farbe im Picker ziehen)
        onTriggered: {
            if (!root.allowed || !root.differs() || sync.running) return
            sync.command = ["pkexec", root.program, "appearance", root.wanted.source || "-", JSON.stringify(root.wanted)]
            sync.running = true
        }
    }
    Process {
        id: sync
        stderr: StdioCollector { id: syncErr }
        onExited: (code) => { if (code !== 0) console.warn("GreeterSync:", code, syncErr.text.trim()) }
    }
}
