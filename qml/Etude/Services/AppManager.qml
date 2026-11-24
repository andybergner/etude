import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Apps: installierte Apps (mit Paket, Größe, Datum), Standard-Apps (mimeapps.list)
// und Autostart (~/.config/autostart, /etc/xdg/autostart).
// Daten liefert scripts/apps-scan.sh, geschrieben wird direkt in die Dateien.
Item {
    id: root
    property Translations tr: Translations { domain: "services" }   // Texte der App

    // [{ id, path, name, icon, comment, exec, terminal, mime: [], pkg, size, date,
    //    scope: "system" | "user", flatpak: "<App-ID>" | "", hiddenForMe }]
    property var apps: []
    property var autostart: []        // [{ id, name, icon, comment, enabled, userPath, systemPath }]
    property var defaults: ({})       // Mime-Typ → Desktop-ID
    property bool loading: false
    property string busy: ""          // Paket, das gerade deinstalliert wird
    property string error: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string etudeHome: Paths.home
    readonly property string script: etudeHome + "/apps/settings/scripts/apps-scan.sh"
    readonly property string autostartDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/autostart"
    readonly property string mimeFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/mimeapps.list"
    property string _userMime: ""     // aktueller Inhalt von ~/.config/mimeapps.list

    // Pakete, ohne die Etude nicht läuft – kein "Deinstallieren"
    readonly property var protectedPkgs: ["quickshell", "hyprland", "kitty", "networkmanager", "pipewire", "wireplumber"]

    // Standard-Apps nach Art (wie Windows: Webbrowser, E-Mail, …)
    readonly property var defaultKinds: [
        { id: "browser", label: tr.t("services.webBrowser"),   desc: tr.t("services.linksAndWebsites"),    icon: 0xF059F,
          mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"] },
        { id: "mail",    label: tr.t("services.email"),       desc: tr.t("services.mailtoLinks"),           icon: 0xF01EE,
          mimes: ["x-scheme-handler/mailto"] },
        { id: "files",   label: tr.t("services.files"),      desc: tr.t("services.openingFolders"),          icon: 0xF024B,
          mimes: ["inode/directory"] },
        { id: "text",    label: tr.t("services.textEditor"),   desc: tr.t("services.textFiles"),            icon: 0xF0219,
          mimes: ["text/plain"] },
        { id: "pdf",     label: "PDF",          desc: tr.t("services.pdfDocuments"),          icon: 0xF0226,
          mimes: ["application/pdf"] },
        { id: "image",   label: tr.t("services.photos"),        desc: tr.t("services.imagesPngJpeg"),  icon: 0xF0976,
          mimes: ["image/png", "image/jpeg", "image/gif", "image/webp"] },
        { id: "music",   label: tr.t("services.music"),        desc: tr.t("services.audioFiles"),           icon: 0xF075A,
          mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"] },
        { id: "video",   label: tr.t("services.video"),        desc: tr.t("services.videoFiles"),           icon: 0xF0567,
          mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime"] }
    ]

    function refresh() { loading = true; appsProc.running = true; autoProc.running = true; mimeProc.running = true }

    function human(bytes) {
        if (!bytes) return ""
        const u = ["B", "KB", "MB", "GB"]
        let i = 0, v = bytes
        while (v >= 1000 && i < u.length - 1) { v /= 1000; i++ }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)).toString().replace(".", ",") + " " + u[i]
    }
    function appById(id) { return apps.find(a => a.id === id) || null }
    function iconSource(icon) {
        if (!icon) return ""
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, true)
    }
    function canUninstall(a) { return !!a && ((!!a.pkg && protectedPkgs.indexOf(a.pkg) < 0) || !!a.flatpak) }

    // ---- Nur für mich ausblenden (wie bei Windows pro Benutzer) ----
    // Eigene Kopie der .desktop-Datei in ~/.local/share/applications mit NoDisplay=true und der
    // Markierung X-Etude-Hidden=true. Die App bleibt installiert (auch „Öffnen mit“ geht weiter),
    // erscheint aber nicht mehr im Startmenü. Einblenden löscht die Kopie wieder.
    readonly property string userAppsDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/applications"
    function setHidden(a, hide) {
        if (!a) return
        const dest = userAppsDir + "/" + a.id
        if (hide) {
            Quickshell.execDetached(["sh", "-c",
                "mkdir -p \"$(dirname \"$2\")\" && " +
                "awk 'BEGIN { g = 0 } /^\\[/ { if (g) { print \"NoDisplay=true\"; print \"X-Etude-Hidden=true\" } g = ($0 == \"[Desktop Entry]\") } " +
                "g && /^(NoDisplay|X-Etude-Hidden)=/ { next } { print } END { if (g) { print \"NoDisplay=true\"; print \"X-Etude-Hidden=true\" } }' " +
                "\"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\"", "sh", a.path, dest])
        } else if (a.hiddenForMe) {
            Quickshell.execDetached(["rm", "-f", a.path])
        }
        refreshTimer.restart()
    }
    Timer { id: refreshTimer; interval: 400; onTriggered: root.refresh() }
    function launch(a) {
        const e = DesktopEntries.byId(a.id.replace(/\.desktop$/, ""))
        if (e) e.execute()
    }

    // ---- Installierte Apps ----
    Process {
        id: appsProc
        command: ["sh", root.script, "apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [], pkgs = {}
                for (const line of this.text.split("\n")) {
                    const f = line.split("\x1f")
                    if (f[0] === "A") {
                        // nur echte, sichtbare Apps – und die, die man selbst ausgeblendet hat
                        const hiddenForMe = f[14] === "true"
                        if (f[7] && f[7] !== "Application") continue
                        if ((f[8] === "true" && !hiddenForMe) || f[9] === "true") continue
                        const path = f[2]
                        const fp = path.indexOf("/flatpak/exports/share/applications/") >= 0 ? f[1].replace(/\.desktop$/, "") : ""
                        list.push({ id: f[1], path: path, name: f[3] || f[1], icon: f[4], comment: f[5], exec: f[6],
                                    terminal: f[13] === "true",           // Terminal=true (z. B. Neovim)
                                    mime: (f[10] || "").split(";").filter(m => m), pkg: "", size: 0, date: 0,
                                    // Für alle Benutzer (pacman, Flatpak system) oder nur für mich (~/.local, Flatpak --user)
                                    scope: path.startsWith(root.home + "/") ? "user" : "system",
                                    flatpak: fp, hiddenForMe: hiddenForMe })
                    } else if (f[0] === "P") {
                        pkgs[f[1]] = { pkg: f[2], size: +f[3] || 0, date: (+f[4] || 0) * 1000 }
                    }
                }
                for (const a of list) {
                    const p = pkgs[a.path]
                    if (p) { a.pkg = p.pkg; a.size = p.size; a.date = p.date }
                }
                root.apps = list.sort((a, b) => a.name.localeCompare(b.name))
                root.loading = false
            }
        }
    }

    // Deinstallieren mit pkexec: die Benutzerkontensteuerung der Shell fragt nach dem Kennwort
    function uninstall(a) {
        if (!canUninstall(a) || uninstallProc.running) return
        busy = a.pkg || a.flatpak
        error = ""
        // Flatpak: für mich (--user, ohne Kennwort) oder für alle (--system, fragt die Benutzerkontensteuerung)
        uninstallProc.command = a.flatpak
            ? ["flatpak", "uninstall", "-y", "--noninteractive", a.scope === "user" ? "--user" : "--system", a.flatpak]
            : ["pkexec", "/usr/bin/pacman", "-Rns", "--noconfirm", "--", a.pkg]
        uninstallProc.running = true
    }
    Process {
        id: uninstallProc
        stderr: StdioCollector { id: uninstallErr }
        onExited: (code) => {
            // 126 = abgebrochen ("Nein"), 127 = nicht berechtigt
            if (code === 126) root.error = ""
            else if (code === 127) root.error = /agent/i.test(uninstallErr.text)
                ? tr.t("services.userAccountControlIsntRunning")
                : tr.t("services.noPermissionToUninstall")
            else if (code !== 0) {
                const msg = uninstallErr.text.trim().split("\n").filter(l => l).pop() || ""
                root.error = /lock|db\.lck/i.test(msg) ? tr.t("services.anotherPackageManagerIsRunning")
                           : (msg || tr.t("services.uninstallingFailed"))
            }
            root.busy = ""
            root.refresh()
        }
    }

    // ---- Standard-Apps ----
    Process {
        id: mimeProc
        command: ["sh", root.script, "mime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {}
                let file = "", section = "", user = []
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("#FILE ")) { file = line.slice(6); section = ""; continue }
                    if (file === root.mimeFile) user.push(line)
                    const t = line.trim()
                    if (t.startsWith("[")) { section = t; continue }
                    if (section !== "[Default Applications]") continue
                    const i = t.indexOf("=")
                    if (i < 0) continue
                    const k = t.slice(0, i).trim()
                    if (d[k] === undefined) d[k] = t.slice(i + 1).split(";").filter(x => x)[0] || ""
                }
                root._userMime = user.join("\n")
                root.defaults = d
            }
        }
    }
    // Apps, die eine Art öffnen können (laut MimeType=), plus die aktuelle Standard-App
    function candidates(kind) {
        const out = apps.filter(a => a.mime.some(m => kind.mimes.indexOf(m) >= 0))
        const cur = defaults[kind.mimes[0]]
        if (cur && !out.some(a => a.id === cur)) {
            const a = appById(cur)
            out.unshift(a || { id: cur, name: cur.replace(/\.desktop$/, "") })
        }
        return out
    }
    function currentDefault(kind) { return defaults[kind.mimes[0]] || "" }
    function setDefault(kind, id) { setDefaultMimes(kind.mimes, id) }
    // Standard-App für einen Mime-Typ (z. B. aus dem Explorer: „Immer diese App verwenden“)
    function setDefaultMime(mime, id) { if (mime) setDefaultMimes([mime], id) }
    // Standard-App eines Mime-Typs (exakt, sonst z. B. image/*), "" = keine
    function defaultFor(mime) {
        if (!mime) return ""
        return defaults[mime] || defaults[mime.split("/")[0] + "/*"] || ""
    }
    // Apps, die einen Mime-Typ öffnen können (Standard-App zuerst)
    function appsFor(mime) {
        if (!mime) return []
        const major = mime.split("/")[0] + "/*"
        const def = defaultFor(mime)
        return apps.filter(a => a.mime.indexOf(mime) >= 0 || a.mime.indexOf(major) >= 0)
            .sort((a, b) => (b.id === def) - (a.id === def) || a.name.localeCompare(b.name))
    }
    function setDefaultMimes(mimes, id) {
        const kind = { mimes: mimes }
        const lines = root._userMime ? root._userMime.split("\n") : []
        let start = lines.findIndex(l => l.trim() === "[Default Applications]")
        if (start < 0) {
            while (lines.length && lines[lines.length - 1].trim() === "") lines.pop()
            if (lines.length) lines.push("")
            lines.push("[Default Applications]")
            start = lines.length - 1
        }
        let end = start + 1
        while (end < lines.length && !lines[end].trim().startsWith("[")) end++
        const body = lines.slice(start + 1, end).filter(l => kind.mimes.indexOf(l.split("=")[0].trim()) < 0)
        while (body.length && body[body.length - 1].trim() === "") body.pop()
        for (const m of kind.mimes) body.push(m + "=" + id + ";")
        const rest = lines.slice(end)
        const out = lines.slice(0, start + 1).concat(body, rest.length ? [""] : [], rest)
        const text = out.join("\n").replace(/\n*$/, "\n")
        root._userMime = text
        mimeOut.setText(text)
        const d = Object.assign({}, root.defaults)
        for (const m of kind.mimes) d[m] = id
        root.defaults = d
    }
    FileView { id: mimeOut; path: root.mimeFile; printErrors: false }

    // ---- Autostart ----
    Process {
        id: autoProc
        command: ["sh", root.script, "autostart"]
        stdout: StdioCollector {
            onStreamFinished: {
                const byId = {}
                for (const line of this.text.split("\n")) {
                    const f = line.split("\x1f")
                    if (f[0] !== "U" && f[0] !== "S") continue
                    const id = f[1]
                    const e = byId[id] || (byId[id] = { id: id, name: "", icon: "", comment: "", hidden: false,
                                                       userPath: "", systemPath: "", only: "", notin: "" })
                    const isUser = f[0] === "U"
                    if (isUser) e.userPath = f[2]; else if (!e.systemPath) e.systemPath = f[2]
                    // Benutzerdatei hat Vorrang; Systemwerte nur auffüllen
                    if (isUser || !e.name) {
                        e.name = f[3] || e.name || id; e.icon = f[4] || e.icon; e.comment = f[5] || e.comment
                        e.only = f[11]; e.notin = f[12]
                    }
                    if (isUser) e.hidden = f[9] === "true"
                    else if (!e.userPath) e.hidden = f[9] === "true"
                }
                const desk = ["Hyprland", "Etude"]
                const fits = (e) => {
                    const only = (e.only || "").split(";").filter(x => x)
                    const notin = (e.notin || "").split(";").filter(x => x)
                    return (only.length === 0 || only.some(x => desk.indexOf(x) >= 0)) && !notin.some(x => desk.indexOf(x) >= 0)
                }
                root.autostart = Object.values(byId).filter(fits)
                    .map(e => ({ id: e.id, name: e.name, icon: e.icon, comment: e.comment, enabled: !e.hidden,
                                 userPath: e.userPath, systemPath: e.systemPath }))
                    .sort((a, b) => a.name.localeCompare(b.name))
            }
        }
    }
    function setAutostart(e, on) {
        const f = root.autostartDir + "/" + e.id
        writeProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && f=\"$2\" && { [ -f \"$f\" ] || cp \"$3\" \"$f\"; } && sed -i '/^Hidden=/d' \"$f\" && " +
            "if [ \"$4\" = off ]; then sed -i '0,/^\\[Desktop Entry\\]/s//[Desktop Entry]\\nHidden=true/' \"$f\"; fi",
            "sh", root.autostartDir, f, e.systemPath || e.userPath, on ? "on" : "off"]
        writeProc.running = true
        root.autostart = root.autostart.map(x => x.id === e.id ? Object.assign({}, x, { enabled: on }) : x)
    }
    function addAutostart(app) {
        writeProc.command = ["sh", "-c", "mkdir -p \"$1\" && cp \"$2\" \"$1/\" && sed -i '/^Hidden=/d' \"$1/$3\"",
                             "sh", root.autostartDir, app.path, app.id]
        writeProc.running = true
    }
    // nur selbst hinzugefügte (ohne Systemeintrag) lassen sich entfernen
    function removeAutostart(e) {
        if (!e.userPath || e.systemPath) return
        writeProc.command = ["rm", "-f", e.userPath]
        writeProc.running = true
    }
    Process {
        id: writeProc
        stderr: StdioCollector { id: writeErr }
        onExited: (code) => { root.error = code === 0 ? "" : (writeErr.text.trim() || tr.t("services.savingFailed")); autoProc.running = true }
    }
}
