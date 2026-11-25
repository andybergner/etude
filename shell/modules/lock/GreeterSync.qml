import QtQuick
import Quickshell
import Quickshell.Io

// Der Anmeldebildschirm folgt automatisch deinem Aussehen: Hintergrund, Hell/Dunkel, Akzentfarbe –
// und deinen Bildschirmen (Auflösung, Skalierung, Anordnung aus Einstellungen › Bildschirm).
// Ändert sich etwas, schreibt die Shell es über `pkexec etude-greeter appearance` bzw.
// `… display` nach /etc/etude/greeter. Eine polkit-Regel erlaubt genau diese Befehle für
// Mitglieder von "wheel" ohne Passwort – sonst wird nicht still synchronisiert.
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
        onExited: (code) => { root.allowed = code === 0; syncTimer.restart(); displayTimer.restart() }
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

    // ---- Bildschirme ----
    // Die Einstellungen schreiben ~/.config/hypr/etude-settings.lua mit einer Zeile
    // "-- etude-monitors: {json}" – genau diese Werte bekommt der Anmeldebildschirm.
    property var monitorsWanted: ({})
    property var monitorsCurrent: ({})
    function canon(o) {
        return JSON.stringify(Object.keys(o || {}).sort().map(k => {
            const m = o[k] || {}
            return [k, m.disabled === true, m.disabled === true ? "" : String(m.mode || ""),
                    parseInt(m.x) || 0, parseInt(m.y) || 0, Number(m.scale) || 1, parseInt(m.transform) || 0]
        }))
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/etude-settings.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^-- etude-monitors: (.*)$/m)
            let v = {}
            if (m) { try { v = JSON.parse(m[1]) || {} } catch (e) { v = {} } }
            root.monitorsWanted = v
            displayTimer.restart()
        }
        onLoadFailed: { root.monitorsWanted = ({}); displayTimer.restart() }
    }
    FileView {
        path: "/etc/etude/greeter/monitors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.monitorsCurrent = JSON.parse(text()) || {} } catch (e) { root.monitorsCurrent = {} } }
        onLoadFailed: root.monitorsCurrent = ({})
    }
    Timer {
        id: displayTimer
        interval: 3000                  // nach „Änderungen beibehalten?“ nicht jeden Zwischenstand
        onTriggered: {
            if (!root.allowed || displaySync.running) return
            if (root.canon(root.monitorsWanted) === root.canon(root.monitorsCurrent)) return
            displaySync.command = ["pkexec", root.program, "display", JSON.stringify(root.monitorsWanted)]
            displaySync.running = true
        }
    }
    Process {
        id: displaySync
        stderr: StdioCollector { id: displayErr }
        onExited: (code) => { if (code !== 0) console.warn("GreeterSync (Bildschirme):", code, displayErr.text.trim()) }
    }
}
