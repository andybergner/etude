import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland-Einstellungen aus der App: schreibt ~/.config/hypr/etude-settings.lua
// (wird von hyprland.lua per pcall(require, "etude-settings") geladen) und lädt neu.
Item {
    id: root

    // "scrolling" (Standard) | "floating" | "dwindle" (Tiling)
    property string layout: "scrolling"
    // Tastatur
    property string kbLayout: "de"
    property string kbVariant: ""
    property bool numlock: true
    // Bildschirme: { "<output>": { mode, position, scale, transform, disabled } }
    property var monitors: ({})
    function setMonitors(m) { monitors = m; save() }

    function monitorsLua() {
        let l = "-- etude-monitors: " + JSON.stringify(monitors) + "\n"
        for (const name in monitors) {
            const m = monitors[name]
            const safe = String(name).replace(/[^A-Za-z0-9_.:-]/g, "")
            if (m.disabled) {
                l += "hl.monitor({ output = \"" + safe + "\", disabled = true })\n"
                continue
            }
            l += "hl.monitor({ output = \"" + safe + "\""
               + ", mode = \"" + String(m.mode).replace(/[^0-9x@.]/g, "") + "\""
               + ", position = \"" + (parseInt(m.x) || 0) + "x" + (parseInt(m.y) || 0) + "\""
               + ", scale = " + (Number(m.scale) || 1)
               + ", transform = " + (parseInt(m.transform) || 0) + " })\n"
        }
        return l
    }

    // Maus und Touchpad
    property var mouse: ({ sensitivity: 0, accel: true, natural: false, leftHanded: false })
    property var touchpad: ({ tap: true, natural: true, dwt: true, scrollFactor: 1.0 })
    property bool hasTouchpad: false
    function setMouse(changes)    { mouse = Object.assign({}, mouse, changes); save() }
    function setTouchpad(changes) { touchpad = Object.assign({}, touchpad, changes); save() }

    // Touchpad vorhanden? (hyprctl devices)
    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | grep -qi touchpad"]
        onExited: (code) => root.hasTouchpad = code === 0
    }

    // Proxy: "none" | "auto" (WPAD/PAC) | "manual"
    property var proxy: ({ mode: "none", pac: "", host: "", port: "", noProxy: "localhost,127.0.0.1,::1" })

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/etude-settings.lua"

    property bool _layoutChanged: false
    function setLayout(l) {
        if (l === layout) return
        layout = l
        _layoutChanged = true
        save()
    }

    function setKeyboard(layout, variant) {
        kbLayout = layout
        kbVariant = variant || ""
        save()
    }
    function setNumlock(on) { numlock = on; save() }

    // Proxy setzen: Umgebungsvariablen für neu gestartete Programme (über Hyprland)
    // und – falls vorhanden – die GNOME-Proxyeinstellungen (Firefox, Chromium, GTK-Apps)
    function setProxy(p) {
        // nur erlaubte Zeichen – die Werte landen in Lua und in einem Shell-Befehl
        p = {
            mode: ["none", "auto", "manual"].indexOf(p.mode) >= 0 ? p.mode : "none",
            pac: (p.pac || "").replace(/[^A-Za-z0-9.:\/_\-?=&%~+]/g, ""),
            host: (p.host || "").replace(/[^A-Za-z0-9.\-_]/g, ""),
            port: String(parseInt(p.port) || ""),
            noProxy: (p.noProxy || "").replace(/[^A-Za-z0-9.,\-_*:\/]/g, "")
        }
        proxy = p
        save()
        let g = "command -v gsettings >/dev/null || exit 0; S=org.gnome.system.proxy;"
        if (p.mode === "manual" && p.host) {
            g += "gsettings set $S mode manual;"
               + "for k in http https ftp; do gsettings set $S.$k host '" + p.host + "'; gsettings set $S.$k port " + (parseInt(p.port) || 8080) + "; done;"
               + "gsettings set $S ignore-hosts \"" + JSON.stringify(p.noProxy.split(",").map(x => x.trim()).filter(x => x)).replace(/"/g, "'") + "\";"
        } else if (p.mode === "auto") {
            g += "gsettings set $S mode auto; gsettings set $S autoconfig-url '" + (p.pac || "") + "';"
        } else {
            g += "gsettings set $S mode none;"
        }
        Quickshell.execDetached(["sh", "-c", g])
    }



    function inputLua() {
        const m = mouse, t = touchpad
        const num = (v, d) => (typeof v === "number" && !isNaN(v) ? v : d)
        return "-- etude-input: " + JSON.stringify({ mouse: m, touchpad: t }) + "\n"
             + "hl.config({ input = {\n"
             + "    sensitivity = " + num(m.sensitivity, 0).toFixed(2) + ",\n"
             + "    accel_profile = \"" + (m.accel ? "adaptive" : "flat") + "\",\n"
             + "    natural_scroll = " + !!m.natural + ",\n"
             + "    left_handed = " + !!m.leftHanded + ",\n"
             + "    touchpad = {\n"
             + "        natural_scroll = " + !!t.natural + ",\n"
             + "        disable_while_typing = " + !!t.dwt + ",\n"
             + "        scroll_factor = " + num(t.scrollFactor, 1).toFixed(2) + ",\n"
             + "    },\n"
             + "} })\n"
             // "Zum Klicken tippen": Name in Lua unklar (tap_to_click / tap-to-click) –
             // nur setzen, was Hyprland kennt; pcall, damit ein Fehler nichts anderes kaputt macht
             + "pcall(function()\n"
             + "    for _, k in ipairs({ \"tap_to_click\", \"tap-to-click\" }) do\n"
             + "        if hl.get_config(\"input.touchpad.\" .. k) ~= nil then\n"
             + "            hl.config({ input = { touchpad = { [k] = " + !!t.tap + " } } })\n"
             + "            break\n"
             + "        end\n"
             + "    end\n"
             + "end)\n"
    }

    function proxyLua() {
        const url = proxy.mode === "manual" && proxy.host ? "http://" + proxy.host + ":" + (parseInt(proxy.port) || 8080) : ""
        const no = proxy.mode === "manual" ? proxy.noProxy : ""
        // auch bei "aus" schreiben (leer), sonst bleibt ein alter Proxy bis zum Neustart gesetzt
        let l = "-- etude-proxy: " + JSON.stringify(proxy) + "\n"
        for (const k of ["http_proxy", "https_proxy", "ftp_proxy", "HTTP_PROXY", "HTTPS_PROXY", "FTP_PROXY"])
            l += "hl.env(\"" + k + "\", \"" + url + "\")\n"
        for (const k of ["no_proxy", "NO_PROXY"])
            l += "hl.env(\"" + k + "\", \"" + no + "\")\n"
        return l
    }

    function save() {
        const hyprLayout = layout === "floating" ? "dwindle" : layout
        let lua = "-- Written by Etude Settings – do not edit by hand.\n"
                + "-- etude-layout: " + layout + "\n\n"
                + "-- etude-kb: " + kbLayout + " " + (kbVariant || "-") + " " + (numlock ? "num" : "nonum") + "\n\n"
                + "hl.config({ general = { layout = \"" + hyprLayout + "\" } })\n"
                + monitorsLua()
                + inputLua()
                + proxyLua()
                + "hl.config({ input = { kb_layout = \"" + kbLayout + "\", kb_variant = \"" + kbVariant + "\", numlock_by_default = " + numlock + " } })\n"
        if (layout === "floating")
            lua += "\n-- All windows float (like Windows/macOS)\n"
                 + "hl.window_rule({ name = \"etude-float-all\", match = { class = \".*\" }, float = true })\n"
        file.setText(lua)
        reloadTimer.restart()
    }

    // Fensterregeln gelten nur für neue Fenster – offene Fenster hier einmal umstellen.
    // Nur Fenster, deren Zustand nicht passt, werden angefasst: Fenster fokussieren,
    // dann schweben lassen bzw. einreihen. Am Ende Fokus zurück aufs aktive Fenster.
    function addr(t) {
        const a = String(t.address)
        return a.startsWith("0x") ? a : "0x" + a
    }
    function applyToOpenWindows() {
        const wantFloat = layout === "floating"
        const active = Hyprland.activeToplevel
        let changed = 0
        for (const t of Hyprland.toplevels.values) {
            const ipc = t.lastIpcObject || {}
            if (ipc.floating === undefined || ipc.floating === wantFloat) continue
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr(t) + "\" })")
            Hyprland.dispatch("hl.dsp.window.float({ action = \"toggle\" })")
            if (wantFloat) Hyprland.dispatch("hl.dsp.window.center()")
            changed++
        }
        if (changed > 0 && active)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr(active) + "\" })")
    }

    FileView {
        id: file
        path: root.path
        onLoaded: {
            const m = /etude-layout:\s*(\w+)/.exec(text())
            if (m) root.layout = m[1] === "master" ? "dwindle" : m[1]
            const mon = /etude-monitors:\s*(\{.*\})/.exec(text())
            if (mon) try { root.monitors = JSON.parse(mon[1]) } catch (e) {}
            const inp = /etude-input:\s*(\{.*\})/.exec(text())
            if (inp) try { const o = JSON.parse(inp[1]); root.mouse = o.mouse; root.touchpad = o.touchpad } catch (e) {}
            const px = /etude-proxy:\s*(\{.*\})/.exec(text())
            if (px) try { root.proxy = JSON.parse(px[1]) } catch (e) {}
            const k = /etude-kb:\s*(\S+)\s+(\S+)\s+(\S+)/.exec(text())
            if (k) {
                root.kbLayout = k[1]
                root.kbVariant = k[2] === "-" ? "" : k[2]
                root.numlock = k[3] === "num"
            }
        }
    }

    // kurz warten, bis die Datei geschrieben ist, dann neu laden
    Timer {
        id: reloadTimer
        interval: 150
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "reload"])
            if (root._layoutChanged) { root._layoutChanged = false; applyTimer.restart() }
        }
    }
    // nach dem Neuladen: Fensterliste samt "floating"-Zustand neu holen …
    Timer {
        id: applyTimer
        interval: 400
        onTriggered: {
            Hyprland.refreshToplevels()
            stateTimer.restart()
        }
    }
    // … und sobald sie da ist, die Fenster anpassen
    Timer {
        id: stateTimer
        interval: 300
        onTriggered: root.applyToOpenWindows()
    }
}
