import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Datenschutz & Sicherheit: Firewall (ufw), Standortdienst (geoclue), Kamera-Nutzung.
// Lesen ohne Kennwort (polkit-Regel für "ufw status"), Ändern über pkexec →
// die Benutzerkontensteuerung der Shell fragt nach dem Kennwort.
Item {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    // ---- Firewall ----
    property bool ufwInstalled: false
    property bool fwEnabled: false
    property string fwIncoming: ""        // Standard für eingehende Verbindungen (z. B. "deny")
    property string fwOutgoing: ""
    property var fwRules: []              // [{ num, to, action, from, v6 }]
    property bool fwBusy: false
    property string fwError: ""

    // ---- Standort ----
    property bool geoInstalled: false
    property bool geoEnabled: false       // nicht maskiert
    property bool geoActive: false        // gerade von einer App benutzt
    property bool geoBusy: false

    // ---- Kamera ----
    property int cameras: 0               // Anzahl /dev/video*
    property var cameraUsers: []          // Programme, die gerade eine Kamera geöffnet haben

    function refreshFirewall() { fwInfo.running = true }
    function refreshLocation() { geoInfo.running = true }
    function refreshCamera() { camInfo.running = true }

    // ===== Firewall =====
    Process {
        id: fwInfo
        command: ["sh", "-c",
            "command -v ufw >/dev/null 2>&1 || [ -x /usr/bin/ufw ] || { echo installed=no; exit 0; }; echo installed=yes; " +
            "grep -q '^ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null && echo enabled=yes || echo enabled=no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ufwInstalled = this.text.indexOf("installed=yes") >= 0
                root.fwEnabled = this.text.indexOf("enabled=yes") >= 0
                if (root.ufwInstalled) { fwVerbose.running = true; fwNumbered.running = true }
                else root.fwRules = []
            }
        }
    }
    // Standardrichtlinien: "Default: deny (incoming), allow (outgoing), disabled (routed)"
    Process {
        id: fwVerbose
        command: ["pkexec", "/usr/bin/ufw", "status", "verbose"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.split("\n").find(l => /^(Default|Standard)/i.test(l)) || ""
                const pick = (dir) => { const m = line.match(new RegExp("(\\w+)\\s*\\(" + dir)); return m ? m[1].toLowerCase() : "" }
                root.fwIncoming = pick("incoming|eingehend")
                root.fwOutgoing = pick("outgoing|ausgehend")
            }
        }
    }
    // Regeln: "[ 1] 22/tcp                     ALLOW IN    Anywhere                   # SSH"
    // IPv4- und IPv6-Eintrag derselben Regel werden zu einer Zeile zusammengefasst.
    Process {
        id: fwNumbered
        command: ["pkexec", "/usr/bin/ufw", "status", "numbered"]
        stdout: StdioCollector {
            onStreamFinished: {
                const groups = [], byKey = {}
                for (const l of this.text.split("\n")) {
                    const m = l.match(/^\[\s*(\d+)\]\s+(.*)$/)
                    if (!m) continue
                    let rest = m[2], comment = ""
                    const hash = rest.indexOf(" # ")
                    if (hash >= 0) { comment = rest.slice(hash + 3).trim(); rest = rest.slice(0, hash) }
                    const cols = rest.split(/\s{2,}/).map(c => c.trim()).filter(c => c)
                    if (cols.length < 3) continue
                    const v6 = /\(v6\)/.test(rest)
                    const to = cols[0].replace(/\s*\(v6\)/, "")
                    const from = cols.slice(2).join(" ").replace(/\s*\(v6\)/, "")
                    const pm = to.match(/^(\d+(?::\d+)?)(?:\/(tcp|udp))?$/)
                    const key = to + "|" + cols[1] + "|" + from + "|" + comment
                    let g = byKey[key]
                    if (!g) {
                        g = byKey[key] = { nums: [], to: to, action: cols[1], from: from, comment: comment,
                                           port: pm ? pm[1] : "", proto: pm && pm[2] ? pm[2] : "",
                                           editable: !!pm, v4: false, v6: false }
                        groups.push(g)
                    }
                    g.nums.push(+m[1])
                    if (v6) g.v6 = true; else g.v4 = true
                }
                root.fwRules = groups
            }
        }
    }

    // Ändern (pkexec → Benutzerkontensteuerung)
    function q(x) { return "'" + String(x).replace(/'/g, "'\\''") + "'" }
    function fwShell(script) {
        if (fwAction.running) return
        fwError = ""
        fwBusy = true
        fwAction.command = ["pkexec", "/usr/bin/sh", "-c", script]
        fwAction.running = true
    }
    function setFirewall(on) {
        fwShell(on ? "ufw --force enable && systemctl enable --now ufw.service"
                   : "ufw disable && systemctl disable --now ufw.service")
    }
    function installUfw() {
        fwShell("pacman -S --needed --noconfirm ufw && ufw default deny incoming && ufw default allow outgoing && " +
                "ufw --force enable && systemctl enable --now ufw.service")
    }
    // r = { action: "allow"|"deny"|"limit", port: "22" | "8000:8100", proto: "tcp"|"udp"|"",
    //       ipv: "both"|"v4"|"v6", comment }
    // "Nur IPv4" = Quelle 0.0.0.0/0, dann legt ufw keinen IPv6-Eintrag an (und umgekehrt mit ::/0).
    function ruleCommand(r) {
        const src = r.ipv === "v4" ? "0.0.0.0/0" : r.ipv === "v6" ? "::/0" : "any"
        let c = "ufw " + r.action + (r.proto ? " proto " + r.proto : "") + " from " + src + " to any port " + q(r.port)
        if (r.comment) c += " comment " + q(r.comment)
        return c
    }
    function deleteCommand(nums) {
        // von hinten löschen, damit die Nummern stimmen
        return nums.slice().sort((a, b) => b - a).map(n => "ufw --force delete " + n).join(" && ")
    }
    function addRule(r) { fwShell(ruleCommand(r)) }
    function deleteRule(g) { fwShell(deleteCommand(g.nums)) }
    function editRule(g, r) { fwShell(deleteCommand(g.nums) + " && " + ruleCommand(r)) }

    Process {
        id: fwAction
        stderr: StdioCollector { id: fwErr }
        onExited: (code) => {
            root.fwBusy = false
            if (code === 126) root.fwError = ""                     // "Nein" in der UAC
            else if (code !== 0) root.fwError = fwErr.text.trim().split("\n").filter(l => l).pop() || tr.t("privacy.thatDidntWork")
            root.refreshFirewall()
        }
    }

    // ===== Standort (geoclue) =====
    Process {
        id: geoInfo
        command: ["sh", "-c",
            "[ -x /usr/lib/geoclue ] || [ -x /usr/libexec/geoclue ] || systemctl cat geoclue.service >/dev/null 2>&1 || { echo installed=no; exit 0; }; " +
            "echo installed=yes; echo enabled=$(systemctl is-enabled geoclue.service 2>/dev/null); echo active=$(systemctl is-active geoclue.service 2>/dev/null)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text
                root.geoInstalled = t.indexOf("installed=yes") >= 0
                root.geoEnabled = root.geoInstalled && t.indexOf("enabled=masked") < 0
                root.geoActive = /active=active\b/.test(t)
            }
        }
    }
    function setLocation(on) {
        if (geoAction.running) return
        geoBusy = true
        geoAction.command = ["pkexec", "/usr/bin/systemctl", on ? "unmask" : "mask", "--now", "geoclue.service"]
        geoAction.running = true
    }
    Process {
        id: geoAction
        onExited: { root.geoBusy = false; root.refreshLocation() }
    }

    // ===== Kamera =====
    // Programme mit offenem /dev/video* (nur eigene Prozesse sind sichtbar – das reicht für Apps)
    Process {
        id: camInfo
        command: ["sh", "-c",
            "echo cams=$(ls /dev/video* 2>/dev/null | wc -l); " +
            "for p in /proc/[0-9]*; do for f in \"$p\"/fd/*; do case $(readlink \"$f\" 2>/dev/null) in /dev/video*) " +
            "echo \"user=$(cat \"$p/comm\" 2>/dev/null)\"; break ;; esac; done; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const c = lines.find(l => l.startsWith("cams="))
                root.cameras = c ? +c.slice(5) || 0 : 0
                root.cameraUsers = lines.filter(l => l.startsWith("user=")).map(l => l.slice(5)).filter(x => x)
            }
        }
    }
}
