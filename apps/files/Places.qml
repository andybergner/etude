import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Orte für den Explorer: persönliche Ordner (XDG), Laufwerke, zuletzt verwendete Dateien.
Item {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    readonly property string home: Quickshell.env("HOME")
    property var folders: []              // [{ id, label, path, icon, glyph }]
    property var drives: []               // [{ label, mount, device, size, used, avail, removable, mounted }]
    property var recent: []               // [{ path, name, time }]
    property string error: ""

    function refresh() { dirsProc.running = true; drivesProc.running = true; recentProc.running = true }
    Component.onCompleted: refresh()

    // ---- persönliche Ordner (~/.config/user-dirs.dirs, sonst englische Standardnamen) ----
    readonly property var known: [
        { id: "DESKTOP",   label: tr.t("files.placeDesktop"),   icon: "user-desktop",     glyph: 0xF01C4, def: "Desktop" },
        { id: "DOWNLOAD",  label: tr.t("files.placeDownloads"), icon: "folder-download",  glyph: 0xF01DA, def: "Downloads" },
        { id: "DOCUMENTS", label: tr.t("files.placeDocuments"), icon: "folder-documents", glyph: 0xF0219, def: "Documents" },
        { id: "PICTURES",  label: tr.t("files.placePictures"),    icon: "folder-pictures",  glyph: 0xF02E9, def: "Pictures" },
        { id: "MUSIC",     label: tr.t("files.placeMusic"),     icon: "folder-music",     glyph: 0xF075A, def: "Music" },
        { id: "VIDEOS",    label: tr.t("files.placeVideos"),    icon: "folder-videos",    glyph: 0xF0567, def: "Videos" }
    ]
    Process {
        id: dirsProc
        // Fehlen die Ordner (frisches System), legt xdg-user-dirs-update sie in der Systemsprache an
        // (Desktop, Downloads, Dokumente, Bilder, Musik, Videos …); ohne das Programm die englischen Namen.
        command: ["sh", "-c",
            "f=\"${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs\"; " +
            "if command -v xdg-user-dirs-update >/dev/null 2>&1; then xdg-user-dirs-update >/dev/null 2>&1; " +
            "elif [ ! -f \"$f\" ]; then mkdir -p \"$HOME/Desktop\" \"$HOME/Downloads\" \"$HOME/Documents\" \"$HOME/Pictures\" \"$HOME/Music\" \"$HOME/Videos\"; fi; " +
            "[ -f \"$f\" ] && grep '^XDG_' \"$f\"; " +
            "for d in \"$HOME\"/*/; do printf 'DIR=%s\\n' \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}, existing = {}
                for (const l of this.text.split("\n")) {
                    const m = l.match(/^XDG_(\w+)_DIR="(.*)"$/)
                    if (m) map[m[1]] = m[2].replace("$HOME", root.home)
                    if (l.startsWith("DIR=")) existing[l.slice(4).replace(/\/$/, "")] = true
                }
                root.folders = root.known.map(k => ({ id: k.id, label: k.label, icon: k.icon, glyph: k.glyph,
                                                     path: map[k.id] || (root.home + "/" + k.def) }))
                    .filter(f => f.path !== root.home && existing[f.path])
            }
        }
    }

    // ---- Laufwerke: eingehängte Dateisysteme (df) + nicht eingehängte Wechseldatenträger (lsblk) ----
    Process {
        id: drivesProc
        command: ["sh", "-c",
            "df -B1 --output=source,target,size,used,avail -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | sed 's/^/DF /'; " +
            "lsblk -rno PATH,RM,TYPE,MOUNTPOINT,SIZE,LABEL 2>/dev/null | sed 's/^/BLK /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, list = [], blk = {}
                for (const l of this.text.split("\n")) {
                    if (!l.startsWith("BLK ")) continue
                    const f = l.slice(4).split(" ")
                    blk[f[0]] = { rm: f[1] === "1", type: f[2], mount: f[3] || "", size: f[4], label: (f.slice(5).join(" ") || "").replace(/\\x20/g, " ") }
                }
                for (const l of this.text.split("\n")) {
                    if (!l.startsWith("DF ")) continue
                    const f = l.slice(3).trim().split(/\s+/)
                    if (f.length < 5) continue
                    const dev = f[0], mount = f[1]
                    if (/^\/(boot|efi)(\/|$)/.test(mount)) continue
                    if (seen[dev]) continue              // btrfs-Subvolumes nur einmal
                    seen[dev] = true
                    const b = blk[dev] || {}
                    list.push({ device: dev, mount: mount, size: +f[2], used: +f[3], avail: +f[4],
                                removable: !!b.rm, mounted: true,
                                label: mount === "/" ? tr.t("files.localDisk") : (b.label || mount.split("/").pop() || dev) })
                }
                // nicht eingehängte Partitionen auf Wechseldatenträgern (USB-Sticks)
                for (const dev in blk) {
                    const b = blk[dev]
                    if (b.rm && b.type === "part" && !b.mount && !seen[dev])
                        list.push({ device: dev, mount: "", size: 0, used: 0, avail: 0, removable: true, mounted: false,
                                    label: b.label || tr.t("files.removableDisk").arg(dev.split("/").pop()), sizeText: b.size })
                }
                list.sort((a, b) => (a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.removable - b.removable))
                root.drives = list
            }
        }
    }
    // USB-Stick einhängen (udisks2, ohne Kennwort für den angemeldeten Benutzer)
    signal mounted(string path)
    function mount(d) {
        mountProc.command = ["udisksctl", "mount", "-b", d.device, "--no-user-interaction"]
        mountProc.running = true
    }
    Process {
        id: mountProc
        stdout: StdioCollector { id: mountOut }
        stderr: StdioCollector { id: mountErr }
        onExited: (code) => {
            if (code === 0) {
                const m = mountOut.text.match(/ at (.+?)\.?\s*$/)
                if (m) root.mounted(m[1])
                root.error = ""
            } else root.error = /not found|No such file/i.test(mountErr.text) && !mountErr.text.includes("Error")
                ? tr.t("files.udisks2IsMissingSudoPacman") : (mountErr.text.trim() || tr.t("files.mountingFailed"))
            drivesProc.running = true
        }
    }
    function unmount(d) {
        mountProc.command = ["sh", "-c", "udisksctl unmount -b \"$1\" --no-user-interaction && udisksctl power-off -b \"$1\" --no-user-interaction 2>/dev/null; true", "sh", d.device]
        mountProc.running = true
    }

    // ---- zuletzt verwendet (~/.local/share/recently-used.xbel) ----
    Process {
        id: recentProc
        command: ["sh", "-c", "cat \"${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const re = /<bookmark\s+href="file:\/\/([^"]+)"[^>]*?modified="([^"]+)"/g
                let m
                while ((m = re.exec(this.text)) !== null) {
                    const path = decodeURIComponent(m[1])
                    out.push({ path: path, name: path.split("/").pop(), time: Date.parse(m[2]) || 0 })
                }
                root.recent = out.sort((a, b) => b.time - a.time).slice(0, 20)
            }
        }
    }
}
