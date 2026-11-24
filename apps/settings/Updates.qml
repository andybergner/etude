import QtQuick
import Quickshell
import Quickshell.Io
import Etude.Services

// Etude Update – Versionen und Updates (für die Seite "Etude Update" und System › Info)
//
//   installed      { "etude": "0.1.0-1", "etude-ui": "0.1.0-1" }   (pacman -Q)
//   dev / devVersion  Entwicklungsmodus (~/.config/etude/dev-home) und `git describe` des Repos
//   etudeUpdates   [{ name, old, new }]  Pakete aus dem Etude-Repo
//   systemUpdates  [{ name, old, new }]  alles andere (Arch)
//
// Suchen läuft ohne Root (checkupdates). Installieren über pkexec:
//   installEtude()  nur Etude-Pakete; brauchen sie neuere Systempakete → needsSystem, nichts passiert
//   installSystem() pacman -Syu (enthält auch die Etude-Updates)
// Das letzte Ergebnis liegt in ~/.local/state/etude/update.json – die Seite zeigt es sofort.
Item {
    id: root

    readonly property string script: Paths.home + "/apps/settings/scripts/update.sh"
    readonly property string repoUrl: "https://github.com/andybergner/etude"

    property var installed: ({})
    property bool dev: false
    property string devVersion: ""

    property string state: "idle"           // idle | checking | installing
    property string error: ""
    property double lastCheck: 0            // ms seit 1970
    property var etudeUpdates: []
    property var systemUpdates: []
    property bool needsSystem: false        // Etude-Update braucht neuere Systempakete
    property string needsSystemPkgs: ""
    property bool needsRelogin: false       // Etude wurde aktualisiert
    property bool rebootRecommended: false  // Kernel o. Ä. aktualisiert
    property string log: ""

    readonly property bool busy: state !== "idle"
    readonly property bool upToDate: lastCheck > 0 && !error && etudeUpdates.length === 0 && systemUpdates.length === 0

    // ---- Versionen ----
    function refreshInstalled() { versions.running = true }
    Process {
        id: versions
        command: ["sh", "-c",
            "pacman -Q etude etude-ui 2>/dev/null | sed 's/^/Q /';" +
            "f=\"${XDG_CONFIG_HOME:-$HOME/.config}/etude/dev-home\";" +
            "if [ -f \"$f\" ]; then echo \"D $(git -C \"$(cat \"$f\")\" describe --tags --always --dirty 2>/dev/null || echo dev)\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const inst = {}
                let dev = false, dv = ""
                for (const line of this.text.split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "Q" && p.length >= 3) inst[p[1]] = p[2]
                    else if (p[0] === "D") { dev = true; dv = p.slice(1).join(" ") }
                }
                root.installed = inst
                root.dev = dev
                root.devVersion = dv
            }
        }
    }

    // ---- Suchen ----
    function check() {
        if (busy) return
        error = ""
        state = "checking"
        checkProc.running = true
    }
    Process {
        id: checkProc
        command: ["sh", root.script, "check"]
        stdout: StdioCollector { id: checkOut }
        stderr: StdioCollector { id: checkErr }
        onExited: (code) => {
            root.state = "idle"
            if (code !== 0 && code !== 2) {
                root.error = (checkErr.text || "").trim().split("\n").slice(-3).join("\n") || ("exit " + code)
                return
            }
            const etudePkgs = {}
            const ups = []
            for (const line of checkOut.text.split("\n")) {
                const p = line.trim().split(/\s+/)
                if (p[0] === "E" && p[1]) etudePkgs[p[1]] = true
                else if (p[0] === "U" && p.length >= 4) ups.push({ name: p[1], old: p[2], new: p[3] })
            }
            root.etudeUpdates = ups.filter(u => etudePkgs[u.name])
            root.systemUpdates = ups.filter(u => !etudePkgs[u.name])
            root.lastCheck = Date.now()
            root.save()
            root.refreshInstalled()
        }
    }

    // ---- Installieren ----
    function installEtude() {
        if (busy || etudeUpdates.length === 0) return
        run(["etude"].concat(etudeUpdates.map(u => u.name)), "etude")
    }
    function installSystem() {
        if (busy) return
        run(["system"], "system")
    }
    function run(args, kind) {
        error = ""
        needsSystem = false
        log = ""
        state = "installing"
        installProc.kind = kind
        installProc.touchesKernel = kind === "system" && systemUpdates.some(u => /^linux(-lts|-zen|-hardened)?$|^nvidia|^mesa$|^systemd$/.test(u.name))
        installProc.command = ["pkexec", "/usr/bin/sh", script].concat(args)
        installProc.running = true
    }
    Process {
        id: installProc
        property string kind: ""
        property bool touchesKernel: false
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("NEEDS_SYSTEM ") === 0) root.needsSystemPkgs = line.slice(13)
                root.log += line + "\n"
            }
        }
        stderr: SplitParser { onRead: (line) => root.log += line + "\n" }
        onExited: (code) => {
            root.state = "idle"
            if (code === 0) {
                if (kind === "etude" || root.etudeUpdates.length > 0) root.needsRelogin = true
                if (touchesKernel) root.rebootRecommended = true
                if (kind === "system") root.systemUpdates = []
                root.etudeUpdates = []
                root.save()
                root.refreshInstalled()
            } else if (code === 3) {
                root.needsSystem = true
            } else if (code === 4) {
                root.error = "locked"
            } else if (code === 126 || code === 127) {
                root.error = "denied"                  // pkexec abgebrochen / nicht berechtigt
            } else {
                root.error = root.log.trim().split("\n").slice(-3).join("\n") || ("exit " + code)
            }
        }
    }

    // ---- „Was ist neu“: Vergleich der Git-Tags auf GitHub ----
    function tagFor(name, version) {
        const prefix = name === "etude-ui" ? "ui-v" : name === "etude" ? "etude-v" : ""
        if (!prefix || !version) return ""
        const m = /^(?:\d+:)?([^-]+)-(\d+)$/.exec(version)
        if (!m) return ""
        return prefix + m[1] + (m[2] === "1" ? "" : "-" + m[2])
    }
    function changesUrl(u) {
        const a = tagFor(u.name, u.old), b = tagFor(u.name, u.new)
        return a && b ? repoUrl + "/compare/" + a + "..." + b : ""
    }

    // Beim Öffnen der Seite: suchen, wenn die letzte Suche älter als eine Stunde ist
    property bool _loaded: false
    property bool _autoPending: false
    function autoCheck() { if (_loaded) _checkIfStale(); else _autoPending = true }
    function _checkIfStale() { if (Date.now() - lastCheck > 3600000) check() }
    function _afterLoad() { _loaded = true; if (_autoPending) { _autoPending = false; _checkIfStale() } }

    // ---- letztes Ergebnis merken ----
    function save() {
        stateFile.setText(JSON.stringify({ lastCheck: lastCheck, etude: etudeUpdates, system: systemUpdates }) + "\n")
    }
    FileView {
        id: stateFile
        path: Paths.state + "/update.json"
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text())
                root.lastCheck = o.lastCheck || 0
                root.etudeUpdates = o.etude || []
                root.systemUpdates = o.system || []
            } catch (e) {}
            root._afterLoad()
        }
        onLoadFailed: root._afterLoad()
    }

    Component.onCompleted: refreshInstalled()
}
