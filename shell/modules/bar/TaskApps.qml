import QtQuick
import Quickshell
import Quickshell.Hyprland
import Etude.Ui
import "../startmenu"

// Apps in der Taskleiste (wie Windows 11): angeheftete Apps und laufende Fenster, nach App gruppiert.
//   Klick: starten bzw. Fenster nach vorne holen; ein Fenster mit Fokus wird minimiert,
//   ein minimiertes wiederhergestellt (mehrere Fenster: nächstes Fenster der App)
//   Mittlere Maustaste: neue Instanz      Rechtsklick: Menü (anheften, schließen …)
//   Hover über einer App mit mehreren Fenstern: Fensterliste (WindowList.qml)
// Minimieren: Hyprland kennt das nicht – das Fenster wandert in den versteckten
// Spezial-Workspace "special:minimized" und beim Wiederherstellen zurück.
// Gekachelte Fenster (z. B. im Scrolling-Layout) lassen sich nicht zuverlässig verschieben:
// sie werden vorher schwebend gemacht und beim Wiederherstellen wieder eingereiht.
// Strich unter dem Icon: läuft (kurz, gedimmt) bzw. hat den Fokus (lang, Akzentfarbe).
Row {
    id: root
    property Translations tr: Translations { domain: "bar" }   // Texte dieses Moduls

    property var pinned: []                // Desktop-IDs, z. B. ["com.etude.files", "kitty"]
    property color fg: Theme.foreground
    property color dim: Theme.mutedForeground

    signal menuRequested(var app, Item button)

    spacing: 2

    // Button unter der Maus und Tooltip-Text (für BarTooltip)
    property Item hoveredItem: null

    // ---- Daten ----
    // reaktiv: die Liste der Desktop-Einträge lädt beim Start asynchron
    readonly property var entries: DesktopEntries.applications.values
    function entryFor(id) {
        if (!id) return null
        id = id.replace(/\.desktop$/, "")
        return entries.find(e => e.id === id || e.id === id + ".desktop") || null
    }
    function matches(entry, id, cls) {
        if (!cls) return false
        const c = cls.toLowerCase()
        if (c === id.toLowerCase()) return true
        if (entry && entry.startupClass && entry.startupClass.toLowerCase() === c) return true
        const h = DesktopEntries.heuristicLookup(cls)
        return !!h && h.id === id
    }
    readonly property var windows: Hyprland.toplevels.values
        .map(t => ({ t: t, o: t.lastIpcObject || {} }))
        .filter(w => w.o.class || w.o.initialClass)
    readonly property var apps: {
        const out = [], used = new Set()
        for (const id of pinned) {
            const e = entryFor(id)
            const wins = windows.filter(w => !used.has(w.t) && matches(e, id, w.o.class || w.o.initialClass))
            wins.forEach(w => used.add(w.t))
            out.push({ key: "pin:" + id, id: id, entry: e, pinned: true,
                       name: e ? e.name : id, icon: e ? e.icon : id, windows: wins })
        }
        // laufende, nicht angeheftete Apps (nach Fensterklasse gruppiert)
        const groups = {}
        for (const w of windows) {
            if (used.has(w.t)) continue
            const cls = w.o.class || w.o.initialClass
            if (!groups[cls]) {
                const e = DesktopEntries.heuristicLookup(cls)
                groups[cls] = { key: "run:" + cls, id: e ? e.id : "", entry: e, pinned: false,
                                name: e ? e.name : cls, icon: e ? e.icon : cls, windows: [] }
                out.push(groups[cls])
            }
            groups[cls].windows.push(w)
        }
        return out
    }

    // ---- Aktionen ----
    readonly property string minimizedWs: "special:minimized"
    function addr(w) {
        const a = w.o.address || (w.t.address ? (String(w.t.address).startsWith("0x") ? w.t.address : "0x" + w.t.address) : "")
        return "address:" + a
    }
    function wsName(w) { return w.t.workspace ? w.t.workspace.name : ((w.o.workspace || {}).name || "") }
    function isMinimized(w) { return wsName(w) === minimizedWs }
    function isFocused(w) { return w.t.activated && !isMinimized(w) }
    // Herkunft minimierter Fenster (Adresse → { ws, tiled }), damit sie dorthin zurückkehren
    property var origin: ({})

    function focusWindow(w) { Hyprland.dispatch("hl.dsp.focus({ window = \"" + addr(w) + "\" })") }
    function minimize(w) {
        const ws = w.t.workspace ? w.t.workspace.id : (w.o.workspace || {}).id
        const tiled = !w.o.floating
        origin[addr(w)] = { ws: ws !== undefined && ws > 0 ? ws : 0, tiled: tiled }
        if (tiled) Hyprland.dispatch("hl.dsp.window.float({ action = \"set\", window = \"" + addr(w) + "\" })")
        Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + minimizedWs + "\", follow = false, window = \"" + addr(w) + "\" })")
        Hyprland.refreshToplevels()
    }
    function restore(w) {
        const cur = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        const o = origin[addr(w)] || { ws: 0, tiled: false }
        delete origin[addr(w)]
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + (o.ws || cur) + ", window = \"" + addr(w) + "\" })")
        if (o.tiled) Hyprland.dispatch("hl.dsp.window.float({ action = \"unset\", window = \"" + addr(w) + "\" })")
        focusWindow(w)
        Hyprland.refreshToplevels()
    }
    // ein Fenster: Fokus → minimieren, minimiert → wiederherstellen, sonst nach vorne holen
    function toggleWindow(w) {
        if (isMinimized(w)) restore(w)
        else if (isFocused(w)) minimize(w)
        else focusWindow(w)
    }
    function launch(app) {
        if (app.entry) app.entry.execute()
        else if (app.id) Quickshell.execDetached(["gtk-launch", app.id])
    }
    function activate(app) {
        if (!app.windows.length) { launch(app); return }
        if (app.windows.length === 1) { toggleWindow(app.windows[0]); return }
        // mehrere Fenster: aktives Fenster der App? → zum nächsten wechseln, sonst das zuletzt benutzte holen
        const ws = app.windows.slice().sort((a, b) => (a.o.focusHistoryID ?? 99) - (b.o.focusHistoryID ?? 99))
        const i = ws.findIndex(w => isFocused(w))
        const next = i >= 0 ? ws[(i + 1) % ws.length] : ws[0]
        if (isMinimized(next)) restore(next); else focusWindow(next)
    }
    function closeWindow(w) { Hyprland.dispatch("hl.dsp.window.close(\"" + addr(w) + "\")") }
    function closeWindows(app) { for (const w of app.windows) closeWindow(w) }
    function findApp(key) { return apps.find(a => a.key === key) || null }

    Repeater {
        model: root.apps
        BarItem {
            id: btn
            required property var modelData
            readonly property var app: modelData
            readonly property bool running: app.windows.length > 0
            readonly property bool focused: app.windows.some(w => root.isFocused(w))
            readonly property bool allMinimized: running && app.windows.every(w => root.isMinimized(w))
            // für den Tooltip in Bar.qml
            // mehrere Fenster: statt des Tooltips erscheint die Fensterliste
            readonly property string tipText: app.windows.length > 1 ? ""
                : app.name + (app.windows.length ? "\n" + (root.isMinimized(app.windows[0]) ? root.tr.t("bar.titleMinimized").arg(app.windows[0].o.title || app.name)
                                                                                         : (app.windows[0].o.title || app.name)) : "")
            padX: 0
            implicitWidth: 40
            onClicked: root.activate(app)
            onRightClicked: root.menuRequested(app, btn)
            onMiddleClicked: root.launch(app)
            onHoveredChanged: if (hovered) root.hoveredItem = btn; else if (root.hoveredItem === btn) root.hoveredItem = null

            // Icon auf einer Kachel wie bei Apple (AppIcon aus dem Startmenü)
            AppIcon {
                size: 30
                tile: true
                name: btn.app.name
                source: btn.app.icon ? (btn.app.icon.startsWith("/") ? "file://" + btn.app.icon : Quickshell.iconPath(btn.app.icon, true)) : ""
            }

            // Anzeige: läuft / hat den Fokus
            Rectangle {
                parent: btn
                visible: btn.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                width: btn.focused ? 16 : 6
                opacity: btn.allMinimized ? 0.5 : 1
                height: 3
                radius: 1.5
                color: btn.focused ? Theme.primary : root.dim
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }
    }
}
