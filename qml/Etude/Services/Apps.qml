import QtQuick
import Quickshell
import Etude.Ui

// Installierte Programme aus den .desktop-Dateien
Item {
    id: root

    // Für die Oberfläche: [{ id, name, generic, keywords, icon }], sortiert nach Name
    readonly property var list: build(DesktopEntries.applications.values)

    property var _entries: ({})                 // id -> DesktopEntry (zum Starten)

    // Eigene Apps: Name und Beschreibung aus dem Katalog, damit sie sofort der Etude-Sprache
    // folgen. Quickshell liest Name[de] usw. nur einmal beim Start (aus LANG/LC_MESSAGES).
    property Translations tr: Translations { domain: "services" }
    readonly property var ownApps: ({
        "com.etude.files":       "services.appFiles",
        "com.etude.settings":    "services.appSettings",
        "com.etude.taskmanager": "services.appTaskManager"
    })
    function displayName(e) {
        const k = e ? ownApps[e.id] : ""
        return k ? tr.t(k) : (e ? e.name || e.id : "")
    }

    function iconUrl(icon) {
        if (!icon) return ""
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, true)  // "" wenn das Theme es nicht kennt
    }

    function build(values) {
        const map = {}
        const out = []
        for (const e of values) {
            if (!e || e.noDisplay || map[e.id]) continue
            map[e.id] = e
            out.push({
                id: e.id,
                name: displayName(e),
                generic: ownApps[e.id] ? tr.t(ownApps[e.id] + "Generic") : (e.genericName || e.comment || ""),
                keywords: (e.keywords || []).concat(ownApps[e.id] ? [e.name] : []).join(" "),
                icon: iconUrl(e.icon)
            })
        }
        _entries = map
        return out.sort((a, b) => a.name.localeCompare(b.name, I18n.language))
    }

    function launch(id) {
        const e = _entries[id]
        if (!e) return
        if (e.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(e.command))
        else e.execute()
    }
}
