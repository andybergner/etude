import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Netzwerk über nmcli (NetworkManager), alle 5 Sekunden
Item {
    id: root
    property Translations tr: Translations { domain: "services" }   // Texte der App

    property string kind: "none"     // "wifi" | "ethernet" | "none"
    property int signal: 0            // WLAN-Signal 0-100
    property string ssid: ""          // Name des WLANs
    property bool wifiEnabled: true
    property bool airplane: false     // alle Funkverbindungen aus

    // WLAN-Liste (für das Untermenü)
    property var networks: []         // [{ ssid, signal, secure, active, known }]
    property var known: []            // gespeicherte WLAN-Verbindungen
    property string connecting: ""
    // Details zur aktiven Verbindung (für die Einstellungen)
    property var info: ({})           // { iface, name, ip, ip6, gateway, mac, dns, speed }
    property bool hasWifi: false      // gibt es überhaupt ein WLAN-Gerät?
    property string connectivity: ""  // "full" | "limited" | "portal" | "none" | "unknown" (NetworkManager)
    property string lastError: ""

    // nmcli trennt Felder mit ":", in Namen ist ":" als "\:" maskiert
    function splitFields(line) {
        const out = []; let cur = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (c === ":") { out.push(cur); cur = ""; continue }
            cur += c
        }
        out.push(cur)
        return out
    }

    function scan() { knownProc.running = true; listProc.running = true }

    function connect(ssid, password) {
        connecting = ssid
        lastError = ""
        let cmd
        if (!password && known.indexOf(ssid) >= 0) cmd = ["nmcli", "connection", "up", "id", ssid]
        else if (password) cmd = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        else cmd = ["nmcli", "device", "wifi", "connect", ssid]
        connectProc.command = cmd
        connectProc.running = true
    }
    function forget(ssid) {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid])
        known = known.filter(k => k !== ssid)
        refreshLater.restart()
    }
    function disconnect(ssid) {
        Quickshell.execDetached(["nmcli", "connection", "down", "id", ssid])
        refreshLater.restart()
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bySsid = {}
                for (const line of this.text.split("\n")) {
                    if (!line) continue
                    const f = root.splitFields(line)
                    const ssid = f[1]
                    if (!ssid) continue
                    const n = { ssid: ssid, signal: parseInt(f[2]) || 0,
                                secure: !!f[3] && f[3] !== "--", active: f[0] === "*",
                                known: root.known.indexOf(ssid) >= 0 }
                    const old = bySsid[ssid]
                    if (!old || n.active || (!old.active && n.signal > old.signal)) bySsid[ssid] = n
                }
                root.networks = Object.values(bySsid).sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            }
        }
    }
    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.known = this.text.split("\n").map(l => root.splitFields(l))
                    .filter(f => f[1] === "802-11-wireless").map(f => f[0])
            }
        }
    }
    Process {
        id: connectProc
        stderr: StdioCollector { id: connectErr }
        onExited: (code) => {
            if (code !== 0) {
                const msg = connectErr.text.trim()
                root.lastError = /secret|password|key/i.test(msg) ? tr.t("services.connectionFailedCheckTheNetwork")
                               : (msg || tr.t("services.connectionFailed"))
            }
            root.connecting = ""
            root.refresh()
            root.scan()
        }
    }

    function refresh() { devProc.running = true; radioProc.running = true; infoProc.running = true; connProc.running = true }

    // Internetzugriff laut NetworkManager (für Tooltip und Menü)
    Process {
        id: connProc
        command: ["nmcli", "-t", "networking", "connectivity"]
        stdout: StdioCollector { onStreamFinished: root.connectivity = this.text.trim() }
    }

    // IP, Gateway, MAC, DNS, Geschwindigkeit – nur mit ip und /sys, ohne NetworkManager
    Process {
        id: infoProc
        command: ["sh", "-c",
            "dev=$(ip -o route show default 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i==\"dev\"){print $(i+1); exit}}');" +
            "gw=$(ip -o route show default 2>/dev/null | awk '{print $3; exit}');" +
            "echo \"wifi=$(ls -d /sys/class/net/*/wireless 2>/dev/null | head -n1)\";" +
            "[ -z \"$dev\" ] && exit 0;" +
            "echo \"iface=$dev\"; echo \"gateway=$gw\";" +
            "echo \"name=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | grep \":$dev$\" | head -n1 | sed 's/:[^:]*$//')\";" +
            "echo \"ip=$(ip -4 -o addr show dev $dev | awk '{print $4; exit}')\";" +
            "echo \"ip6=$(ip -6 -o addr show dev $dev scope global | awk '{print $4; exit}')\";" +
            "echo \"mac=$(cat /sys/class/net/$dev/address 2>/dev/null)\";" +
            "echo \"speed=$(cat /sys/class/net/$dev/speed 2>/dev/null)\";" +
            "echo \"dns=$( (resolvectl dns $dev 2>/dev/null | cut -d: -f2-) || true | xargs)$(grep -m3 ^nameserver /etc/resolv.conf 2>/dev/null | awk '{printf \" %s\", $2}')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                for (const line of this.text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) o[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                root.hasWifi = !!o.wifi
                // DNS: doppelte Einträge entfernen
                o.dns = [...new Set((o.dns || "").split(/\s+/).filter(x => x))].join(", ")
                const sp = parseInt(o.speed)
                o.speed = sp > 0 ? (sp >= 1000 ? (sp / 1000) + " Gbit/s" : sp + " Mbit/s") : ""
                delete o.wifi
                root.info = o
            }
        }
    }

    function setWifi(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
        wifiEnabled = on
        refreshLater.restart()
    }
    function setAirplane(on) {
        Quickshell.execDetached(["nmcli", "radio", "all", on ? "off" : "on"])
        airplane = on
        if (on) wifiEnabled = false
        refreshLater.restart()
    }

    // Verbindungsart – unabhängig von NetworkManager über die Standardroute:
    // Gerät der Default-Route suchen, /sys/class/net/<dev>/wireless => WLAN, sonst Kabel.
    // Ausgabe: "ethernet enp1s0" | "wifi wlan0" | "none"
    Process {
        id: devProc
        command: ["sh", "-c",
            "dev=$(ip -o route show default 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i==\"dev\"){print $(i+1); exit}}');" +
            "if [ -z \"$dev\" ]; then echo none;" +
            "elif [ -d /sys/class/net/$dev/wireless ]; then echo \"wifi $dev\";" +
            "else echo \"ethernet $dev\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const k = this.text.trim().split(" ")[0] || "none"
                root.kind = (k === "wifi" || k === "ethernet") ? k : "none"
                if (root.kind === "wifi") wifiProc.running = true
                else { root.ssid = ""; root.signal = 0 }
            }
        }
    }

    // Signal + Name des aktiven WLANs: "*:72:FRITZ!Box 7590"
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SSID", "device", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.split("\n").find(l => l.startsWith("*"))
                if (!line) { root.signal = 0; root.ssid = ""; return }
                const parts = line.split(":")
                root.signal = parseInt(parts[1]) || 0
                root.ssid = parts.slice(2).join(":").replace(/\\:/g, ":")
            }
        }
    }

    // Funk-Status: "enabled:enabled" (WLAN:Mobilfunk)
    Process {
        id: radioProc
        command: ["nmcli", "-t", "-f", "WIFI,WWAN", "radio"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [wifi, wwan] = this.text.trim().split(":")
                root.wifiEnabled = wifi === "enabled"
                root.airplane = wifi !== "enabled" && wwan !== "enabled"
            }
        }
    }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer { id: refreshLater; interval: 1200; onTriggered: root.refresh() }

    // ===================== Erweitert (für die Einstellungen) =====================
    // Werden nur geladen, wenn eine Seite sie braucht: loadAdvanced() / loadIpConfig(name)

    property var vpns: []             // [{ name, type, active }]
    property var adapters: []         // [{ device, type, state, connection }]
    property var ipConfig: ({})       // { connection, method, address, gateway, dns, dnsAuto }
    property bool busy: false

    function loadAdvanced() { vpnProc.running = true; adapterProc.running = true }

    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.vpns = this.text.split("\n").filter(l => l).map(l => root.splitFields(l))
                .filter(f => /vpn|wireguard/.test(f[1]))
                .map(f => ({ name: f[0], type: f[1] === "wireguard" ? "WireGuard" : "VPN", active: f[2] === "yes" }))
        }
    }
    function vpnToggle(name, on) {
        actionProc.command = ["nmcli", "connection", on ? "up" : "down", "id", name]
        actionProc.running = true
    }

    Process {
        id: adapterProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: root.adapters = this.text.split("\n").filter(l => l).map(l => root.splitFields(l))
                .filter(f => f[1] === "ethernet" || f[1] === "wifi")
                .map(f => ({ device: f[0], type: f[1], state: f[2], connection: f[3] }))
        }
    }
    function adapterToggle(device, on) {
        actionProc.command = ["nmcli", "device", on ? "connect" : "disconnect", device]
        actionProc.running = true
    }

    // IP-Einstellungen einer Verbindung lesen / setzen
    Process {
        id: ipProc
        property string conn: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const v = this.text.split("\n")
                root.ipConfig = {
                    connection: ipProc.conn,
                    method: v[0] === "manual" ? "manual" : "auto",
                    address: (v[1] || "").split(",")[0],
                    gateway: v[2] || "",
                    dns: (v[3] || "").replace(/,/g, ", "),
                    dnsAuto: (v[4] || "no") !== "yes"
                }
            }
        }
    }
    function loadIpConfig(conn) {
        if (!conn) return
        ipProc.conn = conn
        ipProc.command = ["nmcli", "-g", "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.ignore-auto-dns", "connection", "show", conn]
        ipProc.running = true
    }
    // cfg: { method: "auto"|"manual", address: "192.168.1.10/24", gateway, dns: "1.1.1.1, 9.9.9.9" }
    function setIpConfig(conn, cfg) {
        const dns = (cfg.dns || "").split(/[\s,]+/).filter(x => x).join(",")
        let args = ["nmcli", "connection", "modify", conn]
        if (cfg.method === "manual")
            args = args.concat(["ipv4.method", "manual", "ipv4.addresses", cfg.address, "ipv4.gateway", cfg.gateway || ""])
        else
            args = args.concat(["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", ""])
        args = args.concat(["ipv4.dns", dns, "ipv4.ignore-auto-dns", dns ? "yes" : "no"])
        actionProc.after = conn
        actionProc.command = args
        actionProc.running = true
    }

    // Gemeinsamer Ausführer: Fehler landen in lastError, danach wird neu geladen
    Process {
        id: actionProc
        property string after: ""         // nach "modify": Verbindung neu aktivieren
        stderr: StdioCollector { id: actionErr }
        onRunningChanged: root.busy = running
        onExited: (code) => {
            if (code !== 0) {
                root.lastError = /not authorized|permission|polkit/i.test(actionErr.text)
                    ? tr.t("services.noPermissionInstallThePolkit")
                    : actionErr.text.trim()
            } else {
                root.lastError = ""
                if (after) {
                    const c = after; after = ""
                    Quickshell.execDetached(["nmcli", "connection", "up", "id", c])
                }
            }
            reloadAll.restart()
        }
    }
    Timer {
        id: reloadAll
        interval: 1500
        onTriggered: {
            root.refresh(); root.loadAdvanced()
            if (root.ipConfig.connection) root.loadIpConfig(root.ipConfig.connection)
        }
    }
}
