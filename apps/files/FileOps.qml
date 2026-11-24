import QtQuick
import Etude.Ui
import Quickshell
import Etude.Services
import Quickshell.Io

// Dateiaktionen des Explorers über scripts/fileops.sh:
// Zwischenablage (Kopieren/Ausschneiden/Einfügen, auch zwischen Fenstern), Papierkorb,
// Löschen, Neu, Umbenennen, ZIP, Öffnen mit, Eigenschaften.
// Rückgängig (Strg+Z) für Umbenennen, Verschieben, Kopieren, Papierkorb, Neu und ZIP.
// Beim Kopieren großer Datenmengen: Fortschritt (progress) mit Abbrechen.
Item {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    readonly property string etudeHome: Paths.home
    readonly property string script: etudeHome + "/apps/files/scripts/fileops.sh"

    property string busy: ""               // laufende Aktion, z. B. tr.t("files.copying")
    property string error: ""
    property var trashItems: []            // [{ name, path, date, isDir, size }]

    signal changed()                       // etwas wurde verändert (Ansicht neu laden)
    signal created(string path)            // neu angelegt → direkt umbenennen
    signal renamed(string path)
    signal conflict(var names, string mode, string dest, var sources)   // Rückfrage nötig

    function run(args, label, onDone) {
        if (proc.running) { error = tr.t("files.pleaseWaitUntilTheCurrent"); return }
        error = ""
        busy = label || ""
        proc.callback = onDone || null
        proc.lines = []
        proc.command = ["sh", script].concat(args)
        proc.running = true
    }
    Process {
        id: proc
        property var callback: null
        property var lines: []
        property string progressTitle: ""
        stdout: SplitParser { onRead: (line) => { proc.lines.push(line); root.progressLine(line) } }
        stderr: StdioCollector { id: err }
        onExited: (code) => {
            root.busy = ""
            root.endProgress()
            if (code === 130) root.error = tr.t("files.cancelled")
            else if (code !== 0) root.error = err.text.trim().split("\n").filter(l => l).pop() || tr.t("files.theActionFailed")
            const cb = callback
            callback = null
            if (cb) cb(code, lines.join("\n"))
            root.changed()
        }
    }
    // Zeilen mit Feldern (␟ getrennt) einer Art, z. B. "R" → [[quelle, ziel], …]
    function records(text, kind) {
        return text.split("\n").filter(l => l.startsWith(kind + "\x1f")).map(l => l.split("\x1f").slice(1))
    }

    // ===== Fortschritt (Kopieren / Verschieben über Laufwerke) =====
    // Gesamtgröße kommt vom Skript (P␟BYTES), kopierte Bytes misst du regelmäßig an den Zielen.
    property var progress: null            // { title, total, done, targets, started, speed } oder null
    function progressLine(line) {
        const f = line.split("\x1f")
        if (f[0] === "P") {
            progress = { title: proc.progressTitle, total: +f[1] || 0, done: 0, targets: [], started: Date.now(), speed: 0 }
            pollTimer.start()
        } else if (f[0] === "I" && progress) {
            const p = Object.assign({}, progress); p.targets = p.targets.concat([f[1]]); p.current = f[1].split("/").pop(); progress = p
        }
    }
    function endProgress() { pollTimer.stop(); progress = null }
    function cancel() { if (proc.running) proc.signal(15) }
    Timer {
        id: pollTimer
        interval: 600
        repeat: true
        onTriggered: if (root.progress && root.progress.targets.length && !duProc.running) {
            duProc.command = ["du", "-scb", "--"].concat(root.progress.targets)
            duProc.running = true
        }
    }
    Process {
        id: duProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.progress) return
                const last = this.text.trim().split("\n").pop() || ""
                const done = Math.min(+last.split("\t")[0] || 0, root.progress.total)
                const p = Object.assign({}, root.progress)
                const secs = (Date.now() - p.started) / 1000
                p.done = done
                p.speed = secs > 0.5 ? done / secs : 0
                root.progress = p
            }
        }
    }

    // ===== Rückgängig =====
    property var undoStack: []             // [{ label, run: () => … }]
    readonly property string undoLabel: undoStack.length ? undoStack[undoStack.length - 1].label : ""
    function pushUndo(label, fn) { undoStack = undoStack.slice(-19).concat([{ label: label, run: fn }]) }
    function undo() {
        if (!undoStack.length) return
        if (proc.running) { error = tr.t("files.pleaseWaitUntilTheCurrent"); return }
        const u = undoStack[undoStack.length - 1]
        undoStack = undoStack.slice(0, -1)
        u.run()
        root.undone(u.label)
    }
    signal undone(string label)

    // ===== Zwischenablage =====
    // Dateien liegen im Standardformat text/uri-list in der Zwischenablage (wl-copy) – so lassen sie
    // sich auch in andere Programme einfügen (Browser-Upload, Dolphin, Nautilus …). Umgekehrt liest der
    // Explorer text/uri-list und x-special/gnome-copied-files (Nautilus) samt „Ausschneiden“ (auch KDE).
    // „Ausschneiden“ im Explorer selbst: merken wir uns (cutUris), da text/uri-list das nicht kennt.
    function toUri(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/") }
    function fromUri(u) { return decodeURIComponent(u.replace(/^file:\/\//, "").replace(/^localhost/, "")) }
    property var cutUris: []
    function setClipboard(paths, cut) {
        if (!paths.length) return
        const uris = paths.map(toUri)
        cutUris = cut ? uris : []
        Quickshell.execDetached(["sh", "-c", "printf '%s\\r\\n' \"$@\" | wl-copy --type text/uri-list", "sh"].concat(uris))
    }
    // Inhalt der Zwischenablage beobachten (wl-paste --watch ruft das Skript bei jeder Änderung auf):
    // erste Zeile copy|cut, dann die URIs, Ende mit \x1e
    property var clip: ({ mode: "", paths: [] })
    Process {
        id: clipWatch
        running: true
        command: ["wl-paste", "--watch", "sh", "-c",
            "t=$(wl-paste -l 2>/dev/null); has() { printf '%s\\n' \"$t\" | grep -qx \"$1\"; }; " +
            "if has x-special/gnome-copied-files; then wl-paste -n -t x-special/gnome-copied-files; " +
            "elif has text/uri-list; then " +
            "  if has application/x-kde-cutselection && [ \"$(wl-paste -n -t application/x-kde-cutselection)\" = 1 ]; then echo cut; else echo copy; fi; " +
            "  wl-paste -n -t text/uri-list; fi; printf '\\036'"]
        stdout: SplitParser {
            splitMarker: "\x1e"
            onRead: (data) => root.parseClip(data)
        }
        onExited: clipRestart.restart()          // z. B. Sitzung ohne Wayland-Zwischenablage: später erneut
    }
    Timer { id: clipRestart; interval: 5000; onTriggered: clipWatch.running = true }
    function parseClip(data) {
        const lines = String(data).split(/\r?\n/).map(l => l.trim()).filter(l => l && !l.startsWith("#"))
        let mode = "copy"
        if (lines.length && (lines[0] === "copy" || lines[0] === "cut")) mode = lines.shift()
        const uris = lines.filter(l => l.startsWith("file://"))
        // eigenes „Ausschneiden“: gleiche URIs wie beim Ausschneiden
        if (mode === "copy" && cutUris.length && uris.length === cutUris.length && uris.every((u, i) => u === cutUris[i])) mode = "cut"
        clip = { mode: uris.length ? mode : "", paths: uris.map(fromUri) }
    }
    readonly property bool canPaste: clip.paths.length > 0

    // Einfügen aus der Zwischenablage
    function paste(dest) {
        const c = clip
        if (!c.paths.length) return
        transfer(c.paths, dest, c.mode === "cut" ? "move" : "copy")
    }
    // Kopieren/Verschieben (Einfügen, Ziehen und Ablegen): erst Konflikte prüfen, dann ggf. nachfragen
    function transfer(paths, dest, mode) {
        // Verschieben in denselben Ordner ist nichts zu tun
        if (mode === "move") paths = paths.filter(p => (p.slice(0, p.lastIndexOf("/")) || "/") !== dest)
        if (!paths.length) return
        run(["conflicts", dest].concat(paths), "", (code, text) => {
            const names = text.split("\n").filter(l => l)
            if (names.length) root.conflict(names, mode, dest, paths)
            else root.doPaste(mode, "keep", dest, paths)
        })
    }
    function doPaste(mode, policy, dest, sources) {
        const destName = dest === "/" ? tr.t("files.localDisk") : dest.split("/").pop()
        proc.progressTitle = sources.length === 1
            ? tr.t(mode === "move" ? "files.progressMoveOne" : "files.progressCopyOne").arg(sources[0].split("/").pop()).arg(destName)
            : tr.t(mode === "move" ? "files.progressMoveMany" : "files.progressCopyMany").arg(sources.length).arg(destName)
        run(["paste", mode, policy, dest].concat(sources), mode === "move" ? tr.t("files.moving") : tr.t("files.copying"), (code, text) => {
            // Ausschneiden ist nach dem Einfügen verbraucht
            if (code === 0 && mode === "move" && clip.mode === "cut" && sources.every(p => clip.paths.indexOf(p) >= 0)) { cutUris = []; Quickshell.execDetached(["wl-copy", "--clear"]) }
            const done = records(text, "R")                      // [quelle, ziel]
            if (!done.length) return
            const targets = done.map(r => r[1])
            if (mode === "move")
                pushUndo(tr.t("files.move"), () => run(["undomove"].concat(done.reduce((a, r) => a.concat([r[1], r[0]]), [])), tr.t("files.movingBack")))
            else
                pushUndo(tr.t("files.copy"), () => trashQuiet(targets))
        })
    }

    // ===== Papierkorb / Löschen =====
    function trash(paths) {
        if (!paths.length) return
        run(["trash"].concat(paths), tr.t("files.movingToTheRecycleBin"), (code, text) => {
            const names = records(text, "N").map(r => r[0])
            if (names.length) pushUndo(tr.t("files.moveToRecycleBin"), () => restore(names))
        })
    }
    // ohne eigenen Rückgängig-Eintrag (z. B. beim Rückgängigmachen von Kopieren/Neu)
    function trashQuiet(paths) { if (paths.length) run(["trash"].concat(paths), tr.t("files.undoing")) }
    function deleteForever(paths) { if (paths.length) run(["delete"].concat(paths), tr.t("files.deleting")) }
    function loadTrash() {
        trashLoaded = true
        run(["trashlist"], "", (code, text) => {
            root.trashItems = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\x1f")
                return { name: f[0], path: f[1], date: f[2], isDir: f[3] === "1", size: +f[4] || 0 }
            }).sort((a, b) => b.date.localeCompare(a.date))
        })
    }
    function restore(names) { if (names.length) run(["restore"].concat(names), tr.t("files.restoring"), () => { if (root.trashLoaded) loadTrash() }) }
    property bool trashLoaded: false
    function deleteFromTrash(names) { if (names.length) run(["trashdelete"].concat(names), tr.t("files.deleting"), () => loadTrash()) }
    function emptyTrash() { run(["empty"], tr.t("files.emptyingTheRecycleBin"), () => loadTrash()) }

    // ===== Neu / Umbenennen =====
    function newFolder(dest) {
        run(["mkdir", dest, tr.t("files.newFolder")], "", (code, text) => {
            if (code !== 0) return
            const p = text.trim(); root.created(p); pushUndo(tr.t("files.newFolder"), () => trashQuiet([p]))
        })
    }
    function newFile(dest) {
        run(["touch", dest, tr.t("files.newTextDocumentTxt")], "", (code, text) => {
            if (code !== 0) return
            const p = text.trim(); root.created(p); pushUndo(tr.t("files.newFile"), () => trashQuiet([p]))
        })
    }
    function rename(path, name, noUndo) {
        name = name.trim()
        if (!name || name === path.split("/").pop()) return
        run(["rename", path, name], "", (code, text) => {
            if (code !== 0) return
            const np = text.trim()
            root.renamed(np)
            if (!noUndo) pushUndo(tr.t("files.rename"), () => rename(np, path.split("/").pop(), true))
        })
    }

    // ===== ZIP =====
    readonly property var archiveExt: [".zip", ".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.zst", ".tar.bz2", ".7z", ".rar", ".gz", ".xz"]
    function isArchive(path) { const l = path.toLowerCase(); return archiveExt.some(e => l.endsWith(e)) }
    function compress(paths) {
        if (!paths.length) return
        const dest = paths[0].slice(0, paths[0].lastIndexOf("/")) || "/"
        const first = paths[0].split("/").pop()
        const name = (paths.length === 1 ? first.replace(/\.[^./]+$/, "") || first : (dest.split("/").pop() || "Archiv")) + ".zip"
        run(["compress", dest, name].concat(paths), tr.t("files.compressing"), (code, text) => {
            if (code !== 0) return
            const p = text.trim(); root.created(p)
            pushUndo(tr.t("files.createZip"), () => trashQuiet([p]))
        })
    }
    function extract(path, how) {
        run(["extract", path, how], tr.t("files.extracting"), (code, text) => {
            if (code !== 0) return
            const out = text.split("\n").filter(l => l)
            if (out.length) { root.renamedQuiet(out[0]); pushUndo(tr.t("files.extract"), () => trashQuiet(out)) }
        })
    }
    signal renamedQuiet(string path)       // nur auswählen, nicht umbenennen

    // ===== Öffnen mit =====
    // Exec-Zeile der .desktop-Datei mit dem Pfad füllen (%f %F %u %U), übrige Platzhalter entfernen
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function openWith(app, paths) {
        if (!app || !app.exec) return
        let cmd = app.exec
        const files = paths.map(q).join(" ")
        const uris = paths.map(p => q(toUri(p))).join(" ")
        if (/%[fF]/.test(cmd)) cmd = cmd.replace(/%F/g, files).replace(/%f/g, q(paths[0]))
        else if (/%[uU]/.test(cmd)) cmd = cmd.replace(/%U/g, uris).replace(/%u/g, q(toUri(paths[0])))
        else cmd += " " + files
        cmd = cmd.replace(/%[dDnNickvm]/g, "").replace(/%%/g, "%")
        if (app.terminal) {
            // Terminal=true (Neovim, htop …): in einem Terminal starten – xdg-terminal-exec, sonst $TERMINAL, sonst kitty
            Quickshell.execDetached(["setsid", "-f", "sh", "-c",
                'if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec sh -c "$0"; ' +
                'elif [ -n "$TERMINAL" ]; then exec $TERMINAL -e sh -c "$0"; else exec kitty -e sh -c "$0"; fi', cmd])
            return
        }
        Quickshell.execDetached(["setsid", "-f", "sh", "-c", cmd])
    }
    // Mime-Typ einer Datei (für "Öffnen mit")
    // Anfragen werden nacheinander abgearbeitet (mehrere Dateien öffnen, Kontextmenü …)
    property var _mimeQueue: []
    function mimeOf(path, cb) {
        _mimeQueue = _mimeQueue.concat([{ path: path, cb: cb }])
        if (!mimeProc.running && !mimeProc.cb) _nextMime()
    }
    function _nextMime() {
        if (_mimeQueue.length === 0) return
        const j = _mimeQueue[0]
        _mimeQueue = _mimeQueue.slice(1)
        mimeProc.cb = j.cb
        mimeProc.command = ["sh", script, "mime", j.path]
        mimeProc.running = true
    }
    Process {
        id: mimeProc
        property var cb: null
        stdout: StdioCollector { onStreamFinished: {
            const cb = mimeProc.cb
            mimeProc.cb = null
            if (cb) cb(this.text.trim())
            Qt.callLater(root._nextMime)
        } }
    }

    // ===== Eigenschaften =====
    function properties(paths, cb) {
        propsProc.cb = cb
        propsProc.command = ["sh", script, "props"].concat(paths)
        propsProc.running = true
    }
    Process {
        id: propsProc
        property var cb: null
        stdout: StdioCollector {
            onStreamFinished: {
                const r = { items: [], total: 0, files: 0, dirs: 0, mime: "" }
                for (const l of this.text.split("\n")) {
                    const f = l.split("\x1f")
                    if (f[0] === "S") r.items.push({ path: f[1], type: f[2], size: +f[3], created: +f[4] * 1000,
                                                     modified: +f[5] * 1000, accessed: +f[6] * 1000, mode: f[7], owner: f[8], group: f[9] })
                    else if (f[0] === "T") { r.total = +f[1] || 0; r.files = +f[2] || 0; r.dirs = +f[3] || 0 }
                    else if (f[0] === "M") r.mime = f[1]
                }
                if (propsProc.cb) propsProc.cb(r)
                propsProc.cb = null
            }
        }
    }
}
