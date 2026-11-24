import QtQuick
import Quickshell
import Quickshell.Io
import Etude.Ui

// Gemeinsame Etude-Einstellungen – Kompatibilitätsschicht über den Einstellungsbereichen
// (Etude.Ui Config, ~/.config/etude/settings/<domain>.json). Die alten flachen Namen
// (config.dark, config.set("barLayout", …)) bleiben, gespeichert wird je Bereich.
// Neuer Code nimmt direkt Config { domain: "…" }.
Item {
    id: root

    // ---- Werte (mit Standard) ----
    property bool dark: true
    property string accent: ""                 // "" = Standard (Zink), sonst Hex
    property string wallpaperMode: "color"     // "color" (Farbton, Standard) | "image"
    property string wallpaperColor: "#28292d"  // Farbton für den Hintergrund
    property string wallpaper: ""              // Pfad zum Bild (nur bei "image")
    // Sperr- und Anmeldebildschirm: "desktop" (wie Desktop) | "color" | "image"
    property string lockWallpaperMode: "desktop"
    property string lockWallpaperColor: "#28292d"
    property string lockWallpaper: ""
    property string barPosition: "bottom"      // "bottom" | "top"
    // Aufbau der Taskleiste: Elemente je Bereich in Reihenfolge; "hidden" = ausgeblendet
    // Elemente: start, workspaces, apps, network, bluetooth, sound, battery, notifications, clock
    readonly property var defaultBarLayout: ({ left: ["start", "workspaces"], center: [],
        right: ["network", "bluetooth", "sound", "battery", "notifications", "clock"], hidden: ["apps"] })
    property var barLayout: defaultBarLayout
    property var barPinned: ["com.etude.files", "kitty", "com.etude.settings"]   // angeheftete Apps (Desktop-IDs)
    property bool transparency: true           // Taskleiste, Menüs und Apps durchscheinend
    property bool clock24: true                // Uhr im 24-Stunden-Format
    property bool clockSeconds: false          // Sekunden in der Taskleiste
    // Energie: Minuten bis Sperren / Bildschirm aus / Energiesparmodus (0 = nie)
    property int idleAcLock: 5
    property int idleAcScreen: 10
    property int idleAcSuspend: 0
    property int idleBatLock: 3
    property int idleBatScreen: 5
    property int idleBatSuspend: 15
    property bool lockOnSuspend: true          // vor dem Energiesparmodus sperren
    property bool nightLight: false            // Nachtlicht (wärmere Farben, hyprsunset)
    property int nightTemp: 4000               // Farbtemperatur in Kelvin
    // Benachrichtigungen
    property bool notifyEnabled: true          // Benachrichtigungen von Apps und System
    property bool notifyDnd: false             // Nicht stören (nur noch dringende als Banner)
    property bool notifyBanners: true          // Banner anzeigen
    property string notifyPosition: "auto"     // Ecke der Banner: auto | bottom-right | bottom-left | top-right | top-left
    property bool notifySound: true            // Ton abspielen
    property var notifyMuted: []               // Apps ohne Benachrichtigungen (appName)
    property var notifyApps: []                // Apps, die schon etwas gesendet haben: [{ name, icon }]
    // Explorer
    property var filesPinned: []               // im Schnellzugriff angeheftete Ordner (Pfade)
    property bool filesDetails: false          // Detailbereich rechts eingeblendet

    readonly property var keys: ["dark", "accent", "wallpaperMode", "wallpaperColor", "wallpaper",
                                  "lockWallpaperMode", "lockWallpaperColor", "lockWallpaper", "barPosition", "transparency", "clock24", "clockSeconds",
                                  "idleAcLock", "idleAcScreen", "idleAcSuspend",
                                  "idleBatLock", "idleBatScreen", "idleBatSuspend", "lockOnSuspend",
                                  "nightLight", "nightTemp",
                                  "notifyEnabled", "notifyDnd", "notifyBanners", "notifyPosition", "notifySound", "notifyMuted", "notifyApps",
                                  "filesPinned", "filesDetails", "barLayout", "barPinned"]
    // Wo Etude liegt (Repo bzw. /usr/share/etude)
    readonly property string etudeHome: Paths.home
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/etude"

    // Bild nur, wenn der Modus "image" ist – für Desktop und Sperrbildschirm
    readonly property string activeWallpaper: wallpaperMode === "image" ? wallpaper : ""
    // Sperr- und Anmeldebildschirm (Personalisierung › Sperrbildschirm)
    readonly property string lockActiveWallpaper: lockWallpaperMode === "desktop" ? activeWallpaper
                                                : lockWallpaperMode === "image" ? lockWallpaper : ""
    readonly property string lockTint: lockWallpaperMode === "desktop" ? wallpaperColor : lockWallpaperColor

    // Alter Name → [Bereich, Schlüssel]
    readonly property var map: ({
        dark: ["appearance", "dark"], accent: ["appearance", "accent"], transparency: ["appearance", "transparency"],
        wallpaperMode: ["appearance", "wallpaperMode"], wallpaperColor: ["appearance", "wallpaperColor"], wallpaper: ["appearance", "wallpaper"],
        lockWallpaperMode: ["appearance", "lockWallpaperMode"], lockWallpaperColor: ["appearance", "lockWallpaperColor"],
        lockWallpaper: ["appearance", "lockWallpaper"],
        barPosition: ["taskbar", "position"], barLayout: ["taskbar", "layout"], barPinned: ["taskbar", "pinned"],
        clock24: ["time", "clock24"], clockSeconds: ["time", "clockSeconds"],
        idleAcLock: ["power", "idleAcLock"], idleAcScreen: ["power", "idleAcScreen"], idleAcSuspend: ["power", "idleAcSuspend"],
        idleBatLock: ["power", "idleBatLock"], idleBatScreen: ["power", "idleBatScreen"], idleBatSuspend: ["power", "idleBatSuspend"],
        lockOnSuspend: ["power", "lockOnSuspend"],
        nightLight: ["display", "nightLight"], nightTemp: ["display", "nightTemp"],
        notifyEnabled: ["notifications", "enabled"], notifyDnd: ["notifications", "dnd"], notifyBanners: ["notifications", "banners"], notifyPosition: ["notifications", "position"],
        notifySound: ["notifications", "sound"], notifyMuted: ["notifications", "muted"], notifyApps: ["notifications", "apps"],
        filesPinned: ["files", "pinned"], filesDetails: ["files", "details"]
    })
    readonly property var domains: ({ appearance: cAppearance, taskbar: cTaskbar, time: cTime, power: cPower,
                                      display: cDisplay, notifications: cNotifications, files: cFiles })
    Config { id: cAppearance; domain: "appearance" }
    Config { id: cTaskbar; domain: "taskbar" }
    Config { id: cTime; domain: "time" }
    Config { id: cPower; domain: "power" }
    Config { id: cDisplay; domain: "display" }
    Config { id: cNotifications; domain: "notifications" }
    Config { id: cFiles; domain: "files" }
    Instantiator {
        model: Object.keys(root.domains)
        delegate: Connections {
            required property string modelData
            target: root.domains[modelData]
            function onValuesChanged() { root.sync(modelData) }
        }
    }

    // Werte eines Bereichs in die flachen Eigenschaften übernehmen
    // (Listen/Objekte nur bei echter Änderung, sonst feuern Bindungen bei jedem Schreiben)
    function sync(domain) {
        for (const k of keys) {
            const m = map[k]
            if (!m || (domain && m[0] !== domain)) continue
            const v = domains[m[0]].values[m[1]]
            if (v === undefined) continue
            if (typeof v === "object" && v !== null ? JSON.stringify(v) !== JSON.stringify(root[k]) : root[k] !== v) root[k] = v
        }
    }

    function set(key, value) {
        const m = map[key]
        if (!m) { console.warn("EtudeConfig: unknown key", key); return }
        domains[m[0]].set(m[1], value)
    }

    // Einmalig: alte settings.json auf die Bereiche verteilen, danach neu einlesen
    property Process migrate: Process {
        command: ["sh", "-c", "if command -v etude-config >/dev/null; then exec etude-config migrate; else exec \"$ETUDE_HOME/bin/etude-config\" migrate; fi"]
        onExited: {
            for (const d in root.domains) root.domains[d].reload()
            root.sync("")
        }
    }

    Component.onCompleted: { sync(""); migrate.running = true }
}
