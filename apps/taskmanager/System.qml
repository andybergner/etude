import QtQuick
import Etude.Ui
import Quickshell
import Etude.Services
import Quickshell.Io
import Quickshell.Hyprland

// Messwerte für den Task-Manager (scripts/sample.sh alle 1,5 s):
// CPU, Arbeitsspeicher, Datenträger, Netzwerk, GPU und alle Prozesse mit CPU-/RAM-/Datenträger-Last.
// Verlauf je Gerät: die letzten 60 Werte für die Grafiken unter "Leistung".
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    property bool running: true
    property int interval: 1500
    readonly property int historyLength: 60

    readonly property string etudeHome: Paths.home
    readonly property string script: etudeHome + "/apps/taskmanager/scripts/sample.sh"
    readonly property int myUid: _myUid

    // ---- feste Angaben ----
    property string cpuModel: ""
    property int logical: 0
    property int cores: 0
    property int sockets: 1
    property real maxMhz: 0
    property int pageSize: 4096
    property int hz: 100
    property var disks: []                 // [{ name, size, rotational, model }]
    property var nics: []                  // [{ name, kind, speed }]
    property var userNames: ({})           // uid → Name

    // ---- laufende Werte ----
    property real uptime: 0
    property real cpu: 0                   // 0..1
    property var cpuCores: []              // 0..1 je logischem Kern
    property real mhz: 0
    property var mem: ({})                 // Bytes: total, available, used, cached, swapTotal, swapUsed, committed, commitLimit
    property var diskStats: ({})           // name → { read, write (B/s), active (0..1) }
    property var netStats: ({})            // name → { rx, tx (B/s) }
    property real gpu: -1                  // 0..1, -1 = unbekannt
    property var processes: []             // [{ pid, ppid, uid, user, name, state, cpu, mem, disk, threads }]
    property int threadCount: 0

    // ---- Verlauf (60 Werte) ----
    property var history: ({})             // Schlüssel → [Werte]; "cpu", "mem", "disk:vda", "net:enp1s0:rx" …

    function push(h, key, v) {
        const a = (h[key] || []).concat([v])
        h[key] = a.length > historyLength ? a.slice(a.length - historyLength) : a
    }

    // ---- Formatierung ----
    function bytes(b) {
        if (b === undefined || b === null || isNaN(b)) return "–"
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0, v = b
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (v >= 100 || i === 0 ? Math.round(v) : I18n.formatNumber(v, 1)) + " " + u[i]
    }
    function rate(bps) { return bytes(bps) + "/s" }
    function bits(bps) {
        const b = bps * 8
        if (b >= 1e9) return I18n.formatNumber(b / 1e9, 1) + " Gbit/s"
        if (b >= 1e6) return I18n.formatNumber(b / 1e6, 1) + " Mbit/s"
        return Math.round(b / 1e3) + " Kbit/s"
    }
    function percent(v) { return Math.round(v * 100) + " %" }
    function duration(s) {
        s = Math.floor(s)
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60
        const p = (n) => (n < 10 ? "0" : "") + n
        return d + ":" + p(h) + ":" + p(m) + ":" + p(sec)
    }

    // ---- Prozesse beenden ----
    signal killFailed(string message)

    // „Dateispeicherort öffnen“: Programmdatei des Prozesses im Explorer zeigen (ausgewählt),
    // bei Quickshell-Apps die App selbst (scripts/location.sh)
    function openLocation(pid) {
        if (!(pid > 0)) return
        locProc.command = ["sh", etudeHome + "/apps/taskmanager/scripts/location.sh", String(pid)]
        locProc.running = true
    }
    Process {
        id: locProc
        stdout: StdioCollector { id: locOut }
        onExited: {
            const path = locOut.text.trim()
            if (!path) { root.killFailed(tr.t("tm.theLocationOfThisProcess")); return }
            Quickshell.execDetached(["etude-files", path])
        }
    }
    function kill(pids, force) {
        if (!pids || pids.length === 0) return
        const sig = force ? "-KILL" : "-TERM"
        killProc.pids = pids.map(String)
        killProc.sig = sig
        killProc.command = ["kill", sig].concat(killProc.pids)
        killProc.running = true
    }
    Process {
        id: killProc
        property var pids: []
        property string sig: "-TERM"
        stderr: StdioCollector { id: killErr }
        onExited: (code) => {
            // fremde Prozesse (z. B. root): über die Benutzerkontensteuerung
            if (code !== 0 && /not permitted|nicht erlaubt/i.test(killErr.text)) {
                adminKill.command = ["pkexec", "/usr/bin/kill", sig].concat(pids)
                adminKill.running = true
            } else if (code !== 0) root.killFailed(killErr.text.trim())
        }
    }
    Process {
        id: adminKill
        stderr: StdioCollector { id: adminErr }
        onExited: (code) => { if (code !== 0 && code !== 126) root.killFailed(adminErr.text.trim() || tr.t("tm.theProcessCouldNotBe")) }
    }

    // Neuen Task ausführen (optional als Administrator)
    function runTask(cmd, admin) {
        if (!cmd.trim()) return
        Quickshell.execDetached(admin ? ["pkexec", "/usr/bin/sh", "-c", cmd] : ["setsid", "-f", "sh", "-c", cmd])
    }

    // ===== Einlesen =====
    property int _myUid: -1
    Process {
        running: true
        command: ["id", "-u"]
        stdout: StdioCollector { onStreamFinished: root._myUid = parseInt(this.text) }
    }
    Process {
        id: infoProc
        running: true
        command: ["sh", root.script, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const disks = [], nics = [], users = {}
                for (const l of this.text.split("\n")) {
                    const sp = l.indexOf(" ")
                    const tag = l.slice(0, sp), rest = l.slice(sp + 1)
                    const f = rest.split(" ")
                    if (tag === "MODEL") root.cpuModel = rest.trim()
                    else if (tag === "CORES") { root.logical = +f[0] || 0; root.cores = +f[1] || root.logical }
                    else if (tag === "SOCKETS") root.sockets = +f[0] || 1
                    else if (tag === "MAXMHZ") root.maxMhz = (+f[0] || 0) / 1000
                    else if (tag === "PAGESIZE") root.pageSize = +f[0] || 4096
                    else if (tag === "HZ") root.hz = +f[0] || 100
                    else if (tag === "DISK") disks.push({ name: f[0], size: +f[1], rotational: f[2] === "1", model: f.slice(3).join(" ") })
                    else if (tag === "NIC") nics.push({ name: f[0], kind: f[1], speed: +f[2] || 0 })
                    else if (tag === "USER") users[f[0]] = f[1]
                }
                root.disks = disks
                root.nics = nics
                root.userNames = users
            }
        }
    }

    property var _prev: null
    Timer {
        running: root.running
        repeat: true
        triggeredOnStart: true
        interval: root.interval
        onTriggered: {
            if (!sampleProc.running) sampleProc.running = true
            Hyprland.refreshToplevels()
        }
    }
    Process {
        id: sampleProc
        command: ["sh", root.script]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }

    function parse(text) {
        const now = { cpu: [], disks: {}, nets: {}, procs: {}, io: {}, uid: {} }
        const memKb = {}
        let t = 0
        for (const l of text.split("\n")) {
            if (l.startsWith("#T ")) t = parseFloat(l.slice(3))
            else if (l.startsWith("cpu")) {
                const f = l.split(/\s+/)
                const v = f.slice(1).map(Number)
                const idle = (v[3] || 0) + (v[4] || 0)
                const total = v.slice(0, 8).reduce((a, b) => a + b, 0)
                now.cpu.push({ name: f[0], idle: idle, total: total })
            }
            else if (l.startsWith("M ")) {
                const m = l.match(/^M (\w+):\s+(\d+)/)
                if (m) memKb[m[1]] = +m[2]
            }
            else if (l.startsWith("D ")) {
                const f = l.split(" ")
                now.disks[f[1]] = { rs: +f[2], ws: +f[3], io: +f[4] }
            }
            else if (l.startsWith("N ")) {
                const f = l.split(" ")
                now.nets[f[1]] = { rx: +f[2], tx: +f[3] }
            }
            else if (l.startsWith("F ")) root.mhz = +l.slice(2) || 0
            else if (l.startsWith("G ")) root.gpu = (+l.slice(2) || 0) / 100
            else if (l.startsWith("P ")) {
                const f = l.split(" ")
                now.procs[f[1]] = { pid: +f[1], state: f[2], ppid: +f[3], ticks: +f[4], rss: +f[5], threads: +f[6],
                                    name: f.slice(7).join(" ") }
            }
            else if (l.startsWith("U ")) {
                const f = l.split(" ")
                now.uid[f[1].slice(6)] = +f[2]
            }
            else if (l.startsWith("I ")) {
                const f = l.split(" ")
                now.io[f[1].split("/")[2]] = (+f[2] || 0) + (+f[3] || 0)
            }
        }
        now.t = t

        const p = root._prev
        const dt = p ? Math.max(0.1, t - p.t) : 1
        const h = Object.assign({}, root.history)

        // CPU gesamt und je Kern
        let dTotalAll = 1
        if (p && p.cpu.length && now.cpu.length) {
            const a = now.cpu[0], b = p.cpu[0]
            dTotalAll = Math.max(1, a.total - b.total)
            root.cpu = Math.max(0, Math.min(1, 1 - (a.idle - b.idle) / dTotalAll))
            const cores = []
            for (let i = 1; i < now.cpu.length; i++) {
                const c = now.cpu[i], pc = p.cpu[i]
                if (!pc) continue
                const dt2 = Math.max(1, c.total - pc.total)
                cores.push(Math.max(0, Math.min(1, 1 - (c.idle - pc.idle) / dt2)))
            }
            root.cpuCores = cores
            push(h, "cpu", root.cpu)
            cores.forEach((v, i) => push(h, "core" + i, v))
        }

        // Arbeitsspeicher
        const kb = (k) => (memKb[k] || 0) * 1024
        const total = kb("MemTotal"), avail = kb("MemAvailable")
        root.mem = { total: total, available: avail, used: total - avail,
                     cached: kb("Cached") + kb("SReclaimable") + kb("Buffers"), free: kb("MemFree"),
                     swapTotal: kb("SwapTotal"), swapUsed: kb("SwapTotal") - kb("SwapFree"),
                     committed: kb("Committed_AS"), commitLimit: kb("CommitLimit"), shmem: kb("Shmem") }
        push(h, "mem", total > 0 ? (total - avail) / total : 0)

        // Datenträger
        if (p) {
            const ds = {}
            for (const d of root.disks) {
                const a = now.disks[d.name], b = p.disks[d.name]
                if (!a || !b) continue
                const s = { read: Math.max(0, a.rs - b.rs) * 512 / dt, write: Math.max(0, a.ws - b.ws) * 512 / dt,
                            active: Math.max(0, Math.min(1, (a.io - b.io) / (dt * 1000))) }
                ds[d.name] = s
                push(h, "disk:" + d.name, s.active)
                push(h, "disk:" + d.name + ":read", s.read)
                push(h, "disk:" + d.name + ":write", s.write)
            }
            root.diskStats = ds

            const ns = {}
            for (const n of root.nics) {
                const a = now.nets[n.name], b = p.nets[n.name]
                if (!a || !b) continue
                const s = { rx: Math.max(0, a.rx - b.rx) / dt, tx: Math.max(0, a.tx - b.tx) / dt }
                ns[n.name] = s
                push(h, "net:" + n.name + ":rx", s.rx)
                push(h, "net:" + n.name + ":tx", s.tx)
            }
            root.netStats = ns
            if (root.gpu >= 0) push(h, "gpu", root.gpu)
        }
        root.uptime = t
        root.history = h

        // Prozesse
        const list = []
        let threads = 0
        for (const pid in now.procs) {
            const a = now.procs[pid]
            const b = p ? p.procs[pid] : null
            const uid = now.uid[pid] !== undefined ? now.uid[pid] : -1
            const ioNow = now.io[pid], ioPrev = p ? p.io[pid] : undefined
            threads += a.threads
            list.push({
                pid: a.pid, ppid: a.ppid, uid: uid, user: root.userNames[uid] || String(uid),
                name: a.name, state: a.state, threads: a.threads,
                kernel: a.pid === 2 || a.ppid === 2,
                cpu: b ? Math.max(0, (a.ticks - b.ticks) / dTotalAll) : 0,
                mem: a.rss * root.pageSize,
                disk: ioNow !== undefined && ioPrev !== undefined ? Math.max(0, ioNow - ioPrev) / dt : 0
            })
        }
        root.threadCount = threads
        root.processes = list
        root._prev = now
    }
}
