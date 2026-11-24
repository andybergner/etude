pragma Singleton
import QtQuick

// Etude-Theme: shadcn-Farben (zinc), aus oklch umgerechnet mit scripts/oklch2qml.py.
// Achtung: 8-stellige Hexwerte sind in QML #AARRGGBB (Alpha zuerst)!
// Hell/Dunkel, Akzentfarbe und Transparenz kommen vom System (Einstellungsbereich "appearance").
// Jede App mit `import Etude.Ui` folgt damit automatisch den Einstellungen – auch eigenständige
// Apps, die nichts von Etude.Services wissen. followSystem: false schaltet das ab (z. B. Vorschauen).
QtObject {
    id: theme

    // ---- Systemeinstellungen lesen (Bereich "appearance", siehe Config.qml) ----
    property bool followSystem: true
    property Config _appearance: Config { domain: theme.followSystem ? "appearance" : "" }
    property Connections _appearanceChanged: Connections {
        target: theme._appearance
        function onValuesChanged() { theme._applySystem() }
    }
    function _applySystem() {
        if (!followSystem) return
        const v = _appearance.values
        wantDark = v.dark !== undefined ? !!v.dark : true
        wantBrand = v.accent || "transparent"
        wantTransparency = v.transparency !== undefined ? !!v.transparency : true
    }
    Component.onCompleted: _applySystem()

    // ---- Theme wechseln ohne Flackern ----
    // Die "want…"-Werte kommen aus den Systemeinstellungen (oben). Theme schaltet dann
    // zuerst alle Farb-Animationen ab, wechselt die Farben auf einen Schlag und
    // schaltet die Animationen kurz danach wieder ein. Sonst laufen Flächen mit und
    // ohne Animation auseinander → kurzes Aufblitzen der alten Farben.
    property bool wantDark: true
    property color wantBrand: "transparent"
    property bool wantTransparency: true
    property bool animate: true             // Behavior { enabled: Theme.animate }

    function _switch(fn) { animate = false; fn(); _resume.restart() }
    onWantDarkChanged: _switch(() => dark = wantDark)
    onWantBrandChanged: _switch(() => brand = wantBrand)
    onWantTransparencyChanged: _switch(() => transparency = wantTransparency)
    property Timer _resume: Timer { interval: 300; onTriggered: theme.animate = true }

    property bool dark: true
    // Akzentfarbe aus den Einstellungen ("transparent" = Standard aus der Palette)
    property color brand: "transparent"
    readonly property bool hasBrand: brand.a > 0
    // Transparenzeffekte: Flächen durchscheinend, Hyprland zeichnet dahinter Blur
    property bool transparency: true
    readonly property real glass: transparency ? 0.72 : 1        // Leiste, Sidebar
    readonly property real glassPopover: transparency ? 0.82 : 1 // Menüs, Popups
    readonly property real glassWindow: transparency ? 0.80 : 1  // App-Fenster
    readonly property real glassCard: transparency ? 0.55 : 1    // Karten, Felder (liegen auf dem Fenster)
    // Fläche je nach Transparenz durchscheinend machen
    function t(c, a) { const x = Qt.color(c); return transparency ? Qt.rgba(x.r, x.g, x.b, a) : x }
    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    // ---- Farben (shadcn: --background, --foreground, ...) ----
    property color background:                t(dark ? "#09090b" : "#ffffff", glassWindow)
    property color foreground:                dark ? "#fafafa" : "#09090b"
    property color card:                      t(dark ? "#18181b" : "#ffffff", glassCard)
    property color cardForeground:            dark ? "#fafafa" : "#09090b"
    property color popover:                   t(dark ? "#18181b" : "#ffffff", glassPopover)
    property color popoverForeground:         dark ? "#fafafa" : "#09090b"
    property color primary:                   hasBrand ? brand : (dark ? "#e4e4e7" : "#18181b")
    property color primaryForeground:         hasBrand ? (luminance(brand) > 0.6 ? "#18181b" : "#fafafa")
                                                       : (dark ? "#18181b" : "#fafafa")
    property color secondary:                 t(dark ? "#27272a" : "#f4f4f5", glassCard)
    property color secondaryForeground:       dark ? "#fafafa" : "#18181b"
    property color muted:                     t(dark ? "#27272a" : "#f4f4f5", glassCard)
    property color mutedForeground:           dark ? "#9f9fa9" : "#71717b"
    // Hover-Flächen: bei Transparenz halbdurchsichtig, sonst deckend
    property color accent:                    transparency ? (dark ? "#1affffff" : "#0f000000")
                                                           : (dark ? "#27272a" : "#f4f4f5")
    property color accentForeground:          dark ? "#fafafa" : "#18181b"
    property color destructive:               dark ? "#ff6467" : "#e7000b"
    // Statusfarben (Tailwind green-500/600, amber-500/600)
    property color success:                   dark ? "#22c55e" : "#16a34a"
    property color warning:                   dark ? "#f59e0b" : "#d97706"
    property color border:                    dark ? "#1affffff" : "#e4e4e7"
    property color input:                     dark ? "#26ffffff" : "#e4e4e7"
    property color ring:                      hasBrand ? brand : (dark ? "#71717b" : "#9f9fa9")
    property color chart1:                    dark ? "#1447e6" : "#f54900"
    property color chart2:                    dark ? "#00bc7d" : "#009689"
    property color chart3:                    dark ? "#fe9a00" : "#104e64"
    property color chart4:                    dark ? "#ad46ff" : "#ffb900"
    property color chart5:                    dark ? "#ff2056" : "#fe9a00"
    property color sidebar:                   t(dark ? "#18181b" : "#fafafa", glass)
    property color sidebarForeground:         dark ? "#fafafa" : "#09090b"
    // wie primary (shadcn-Standard wäre im Dunkeln Blau – passt nicht zu zinc)
    property color sidebarPrimary:            primary
    property color sidebarPrimaryForeground:  primaryForeground
    property color sidebarAccent:             transparency ? (dark ? "#1fffffff" : "#14000000")
                                                           : (dark ? "#27272a" : "#f4f4f5")
    property color sidebarAccentForeground:   dark ? "#fafafa" : "#18181b"
    property color sidebarBorder:             dark ? "#1affffff" : "#e4e4e7"
    property color sidebarRing:               dark ? "#71717b" : "#9f9fa9"

    // ---- Breite der Menüs an der Taskleiste (Netzwerk, Sound, Kalender, Benachrichtigungen …) ----
    readonly property real menuWidth: 360

    // ---- Radien (shadcn: --radius 0.5rem = 8px) ----
    property real radius: 8
    readonly property real radiusLg: radius          // rounded-lg
    readonly property real radiusMd: radius - 2      // rounded-md
    readonly property real radiusSm: radius - 4      // rounded-sm
    readonly property real radiusXl: radius + 4      // rounded-xl

    // ---- Schrift ----
    property string fontSans: "Inter"
    property string fontMono: "JetBrainsMono Nerd Font"
    property string fontIcon: "JetBrainsMono Nerd Font"   // Nerd-Font-Icons (nf-md-*)

    // ---- Animation (Tailwind transition = 150ms) ----
    property int duration: 150

    // ---- Hilfsfunktionen ----
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, p) {                         // color-mix(in srgb, a, b p%)
        return Qt.rgba(a.r + (b.r - a.r) * p, a.g + (b.g - a.g) * p,
                       a.b + (b.b - a.b) * p, a.a + (b.a - a.a) * p)
    }
}
