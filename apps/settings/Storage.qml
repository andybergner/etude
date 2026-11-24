import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Speicher: Belegung von / und den Ordnern, Laufwerke, Aufräumen
Item {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property var root_: ({})          // { size, used, avail, percent } für "/"
    property var drives: []           // [{ source, mount, fs, size, used, avail, percent }]
    property var sizes: ({})          // Bytes je Kategorie (siehe sizeProc)
    property bool scanning: false
    property string cleaning: ""      // gerade laufende Aufräum-Aktion
    property string error: ""

    function refresh() { dfProc.running = true; scanning = true; sizeProc.running = true }

    function human(bytes) {
        if (bytes === undefined || bytes === null || isNaN(bytes)) return "–"
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0, v = bytes
        while (v >= 1000 && i < u.length - 1) { v /= 1000; i++ }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)).toString().replace(".", ",") + " " + u[i]
    }

    // ---- Laufwerke (df) ----
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=source,target,fstype,size,used,avail",
                  "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                const list = []
                for (const l of this.text.split("\n").slice(1)) {
                    const f = l.trim().split(/\s+/)
                    if (f.length < 6) continue
                    const d = { source: f[0], mount: f[1], fs: f[2], size: +f[3], used: +f[4], avail: +f[5] }
                    d.percent = d.size > 0 ? d.used / d.size : 0
                    if (d.mount === "/") root.root_ = d
                    // btrfs-Subvolumes (/home, /var/log …) liegen auf demselben Gerät – nur einmal zeigen
                    if (seen[d.source]) continue
                    seen[d.source] = true
                    list.push(d)
                }
                root.drives = list
            }
        }
    }

    // ---- Größen je Kategorie (du, kann ein paar Sekunden dauern) ----
    Process {
        id: sizeProc
        command: ["sh", "-c",
            "s() { du -sb \"$2\" 2>/dev/null | awk -v k=\"$1\" '{print k\"=\"$1}'; };" +
            "H=\"$HOME\";" +
            "for d in Dokumente:Documents Bilder:Pictures Downloads:Downloads Videos:Videos Musik:Music; do " +
            "  de=${d%%:*}; en=${d##*:}; [ -d \"$H/$de\" ] && s \"$de\" \"$H/$de\" || { [ -d \"$H/$en\" ] && s \"$de\" \"$H/$en\"; }; done;" +
            "s home \"$H\"; s cache \"$H/.cache\"; s thumbs \"$H/.cache/thumbnails\";" +
            "s trash \"$H/.local/share/Trash\"; s pkg /var/cache/pacman/pkg; s usr /usr;" +
            "echo \"journal=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]?B?' | head -n1)\";" +
            "echo \"pkgcount=$(ls /var/cache/pacman/pkg/*.pkg.tar.* 2>/dev/null | wc -l)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                for (const l of this.text.split("\n")) {
                    const i = l.indexOf("=")
                    if (i > 0) o[l.slice(0, i)] = l.slice(i + 1)
                }
                // journalctl gibt "1.2G" o. ä. aus → in Bytes umrechnen
                const m = /^([\d.]+)([KMGT]?)/.exec(o.journal || "")
                o.journal = m ? parseFloat(m[1]) * ({ "": 1, K: 1024, M: 1048576, G: 1073741824, T: 1099511627776 })[m[2]] : NaN
                for (const k in o) if (k !== "journal") o[k] = +o[k]
                root.sizes = o
                root.scanning = false
            }
        }
    }

    // ---- Aufräumen ----
    // Ohne root: Papierkorb, Miniaturansichten
    // Mit root über pkexec (ohne Passwort dank polkit-Regel, nur genau diese Befehle):
    //   Paket-Cache: paccache -rk1 (aus pacman-contrib)   Protokolle: journalctl --vacuum-size=100M
    readonly property var actions: ({
        trash:   ["sh", "-c", "rm -rf \"$HOME\"/.local/share/Trash/files/* \"$HOME\"/.local/share/Trash/info/* 2>/dev/null; true"],
        thumbs:  ["sh", "-c", "rm -rf \"$HOME\"/.cache/thumbnails/* 2>/dev/null; true"],
        pkg:     ["pkexec", "/usr/bin/paccache", "-rk1"],
        journal: ["pkexec", "/usr/bin/journalctl", "--vacuum-size=100M"]
    })
    function clean(what) {
        if (cleaning) return
        error = ""
        cleaning = what
        cleanProc.command = actions[what]
        cleanProc.running = true
    }
    Process {
        id: cleanProc
        stderr: StdioCollector { id: cleanErr }
        onExited: (code) => {
            if (code !== 0) {
                const t = cleanErr.text
                root.error = /No such file|not found/.test(t) && root.cleaning === "pkg"
                    ? tr.t("storage.paccacheMissing")
                    : /authoriz|polkit|agent|dismissed/i.test(t)
                    ? tr.t("settings.noPermission")
                    : (t.trim() || tr.t("storage.cleanupFailed"))
            }
            root.cleaning = ""
            root.refresh()
        }
    }
}
