import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Dienste (systemd): Liste mit Status und Starttyp, Starten/Beenden/Neu starten.
// Systemdienste ändern geht über pkexec → Benutzerkontensteuerung; Benutzerdienste direkt.
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    property bool user: false              // false = Systemdienste, true = Benutzerdienste
    property var services: []              // [{ name, description, active, sub, state ("running"|"stopped"|"failed"), startup }]
    property bool loading: false
    property string error: ""

    onUserChanged: refresh()
    function refresh() { loading = true; listProc.running = true }

    Process {
        id: listProc
        command: ["sh", "-c",
            "s=\"\"; [ \"$1\" = user ] && s=--user; " +
            "echo '#UNITS'; systemctl $s list-units --type=service --all --no-legend --plain --no-pager; " +
            "echo '#FILES'; systemctl $s list-unit-files --type=service --no-legend --no-pager",
            "sh", root.user ? "user" : "system"]
        stdout: StdioCollector {
            onStreamFinished: {
                const units = {}, files = {}
                let sec = ""
                for (const l of this.text.split("\n")) {
                    if (l.startsWith("#")) { sec = l; continue }
                    const t = l.trim()
                    if (!t) continue
                    const f = t.split(/\s+/)
                    if (sec === "#UNITS" && f[0].endsWith(".service"))
                        units[f[0]] = { load: f[1], active: f[2], sub: f[3], description: f.slice(4).join(" ") }
                    else if (sec === "#FILES" && f[0].endsWith(".service"))
                        files[f[0]] = f[1]
                }
                const names = new Set(Object.keys(units).concat(Object.keys(files).filter(n => !n.includes("@.") )))
                const list = []
                for (const n of names) {
                    const u = units[n] || { load: "", active: "inactive", sub: "dead", description: "" }
                    if (u.load === "not-found" && !files[n]) continue
                    const file = files[n] || ""
                    list.push({
                        name: n.replace(/\.service$/, ""),
                        unit: n,
                        description: u.description,
                        state: u.active === "active" ? "running" : u.active === "failed" ? "failed" : "stopped",
                        sub: u.sub,
                        startup: file === "enabled" || file === "enabled-runtime" ? tr.t("tm.automatic")
                               : file === "disabled" ? tr.t("tm.manual")
                               : file === "masked" ? tr.t("tm.disabled")
                               : file === "static" ? tr.t("tm.static") : file ? file : "–"
                    })
                }
                root.services = list.sort((a, b) => a.name.localeCompare(b.name))
                root.loading = false
            }
        }
    }

    // action: "start" | "stop" | "restart"
    function control(s, action) {
        error = ""
        ctlProc.command = root.user ? ["systemctl", "--user", action, s.unit]
                                    : ["pkexec", "/usr/bin/systemctl", action, s.unit]
        ctlProc.running = true
    }
    Process {
        id: ctlProc
        stderr: StdioCollector { id: ctlErr }
        onExited: (code) => {
            if (code !== 0 && code !== 126) root.error = ctlErr.text.trim().split("\n").pop() || tr.t("tm.thatDidntWork")
            root.refresh()
        }
    }
}
