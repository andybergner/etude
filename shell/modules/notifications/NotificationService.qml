// Benachrichtigungsdienst der Shell (org.freedesktop.Notifications).
// Hält den Verlauf (Benachrichtigungscenter) und die Banner, die gerade sichtbar sind.
// Es darf nur EIN Dienst laufen: mako, dunst, swaync usw. vorher beenden.
//
// Verlauf über Neustarts: ~/.local/state/etude/notifications.json
// Laufende Benachrichtigungen sind Quickshell-Objekte (mit Aktionen). Nach einem Neustart
// kommen sie als einfache Einträge zurück (Titel, Text, App, Zeit – ohne Aktionen).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "NotifyType.js" as NotifyType

Scope {
    id: root

    property var settings                          // EtudeConfig

    readonly property bool enabled: settings ? settings.notifyEnabled : true
    readonly property bool dnd: settings ? settings.notifyDnd : false

    // Gespeicherte Einträge aus früheren Sitzungen (einfache Objekte)
    property var stored: []
    readonly property int maxStored: 50

    readonly property var live: server.trackedNotifications.values

    // Verlauf: neueste zuerst (laufende und gespeicherte gemischt)
    readonly property var list: live.slice().reverse().concat(stored)
    readonly property int count: live.length + stored.length

    // Banner, die gerade angezeigt werden (älteste zuerst)
    property var popups: []
    readonly property int maxPopups: 4

    // Center offen → keine Banner (wie Windows)
    property bool centerOpen: false
    onCenterOpenChanged: if (centerOpen) popups = []

    // Eingangszeit je laufender Benachrichtigung (für "vor 5 Min.")
    property var times: ({})

    signal centerRequested()

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/etude"

    function isStored(n) { return !!n && typeof n.dismiss !== "function" }
    function isMuted(app) {
        return !!settings && (settings.notifyMuted || []).indexOf(app) >= 0
    }
    function timeOf(n) {
        if (!n) return Date.now()
        if (isStored(n)) return n.time
        return times[n.id] || Date.now()
    }

    function hidePopup(n) { popups = popups.filter(p => p && p !== n) }
    function removeStored(n) { stored = stored.filter(s => s !== n) }

    // Klick auf eine Benachrichtigung: Standardaktion auslösen (App öffnet sich), dann entfernen
    function activate(n) {
        if (!n) return
        if (isStored(n)) { removeStored(n); return }
        const def = (n.actions || []).find(a => a.identifier === "default")
        if (def) def.invoke()
        else n.dismiss()
        hidePopup(n)
    }
    function invoke(n, action) {
        action.invoke()
        hidePopup(n)
    }
    function dismiss(n) {
        if (!n) return
        if (isStored(n)) { removeStored(n); return }
        hidePopup(n)
        n.dismiss()
    }
    function clearAll() {
        popups = []
        stored = []
        for (const n of live.slice()) n.dismiss()
    }
    function clearApp(app) {
        stored = stored.filter(s => (s.appName || "") !== app)
        for (const n of live.slice())
            if ((n.appName || "") === app) dismiss(n)
    }
    function setDnd(on) { if (settings) settings.set("notifyDnd", on) }

    // App merken, damit sie in den Einstellungen auftaucht
    function rememberApp(n) {
        if (!settings) return
        const name = n.appName || ""
        if (name === "") return
        const apps = settings.notifyApps || []
        if (apps.some(a => a.name === name)) return
        settings.set("notifyApps", apps.concat([{ name: name, icon: n.appIcon || n.desktopEntry || "" }]))
    }

    // ---- Speichern / Laden ----
    // Bilder nur behalten, wenn sie als Datei vorliegen (image://… gibt es nach dem Neustart nicht mehr)
    function toEntry(n) {
        const img = n.image || ""
        return {
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            desktopEntry: n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,
            type: NotifyType.of(n),                       // Erfolg/Fehler/Warnung (Hinweise gibt es im Verlauf nicht mehr)
            image: (img.startsWith("/") || img.startsWith("file://")) ? img : "",
            time: timeOf(n)
        }
    }
    function save() {
        if (!stateFile.ready) return
        const entries = live.filter(n => !n.transient).map(toEntry).reverse()
            .concat(stored.map(s => toEntry(s)))
            .slice(0, maxStored)
        stateFile.setText(JSON.stringify(entries, null, 1) + "\n")
    }

    Timer { id: saveTimer; interval: 500; onTriggered: root.save() }
    onStoredChanged: saveTimer.restart()
    onLiveChanged: saveTimer.restart()

    FileView {
        id: stateFile
        property bool ready: false
        path: root.stateDir + "/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const arr = JSON.parse(text())
                if (Array.isArray(arr)) root.stored = arr.filter(e => e && (e.summary || e.body)).slice(0, root.maxStored)
            } catch (e) { console.warn("notifications.json:", e) }
            ready = true
        }
        onLoadFailed: ready = true                 // Datei gibt es noch nicht
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.stateDir])

    NotificationServer {
        id: server
        keepOnReload: false               // nach einem Reload kommen sie aus der Datei zurück (keine Doppelten)
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            root.rememberApp(n)
            const app = n.appName || ""
            // ausgeschaltet oder App stumm: gar nicht annehmen
            if (!root.enabled || root.isMuted(app)) return

            n.tracked = true
            const t = root.times; t[n.id] = Date.now(); root.times = t

            const critical = n.urgency === NotificationUrgency.Critical
            const banner = root.settings.notifyBanners && !root.centerOpen && (!root.dnd || critical)
            if (banner) {
                let p = root.popups.filter(x => x && x !== n).concat([n])
                if (p.length > root.maxPopups) p = p.slice(p.length - root.maxPopups)
                root.popups = p
                if (root.settings.notifySound && !n.hints["suppress-sound"])
                    sound.running = true
            } else if (n.transient) {
                n.expire()                       // flüchtig und kein Banner → nicht in den Verlauf
            }
            n.closed.connect(() => root.hidePopup(n))
        }
    }

    // Hinweiston (freedesktop-Soundtheme, falls installiert)
    Process {
        id: sound
        command: ["sh", "-c",
            "f=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga; " +
            "[ -f \"$f\" ] || f=/usr/share/sounds/freedesktop/stereo/message.oga; " +
            "[ -f \"$f\" ] && exec pw-play \"$f\"; true"]
    }

    //   qs -p $ETUDE_HOME/shell ipc call notifications dnd
    IpcHandler {
        target: "notifications"
        function center(): void { root.centerRequested() }
        function dnd(): void { root.setDnd(!root.dnd) }
        function clear(): void { root.clearAll() }
        function status(): string {
            return "enabled=" + root.enabled + " dnd=" + root.dnd +
                   " live=" + root.live.length + " stored=" + root.stored.length +
                   " banner=" + root.popups.length
        }
    }
}
