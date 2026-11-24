// Etude-Shell: Einstiegspunkt
// Entwicklung: qs -p $ETUDE_HOME/shell
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import Etude.Ui
import Etude.Services
import "modules/background"
import "modules/idle"
import "modules/display"
import "modules/bar"
import "modules/lock"
import "modules/notifications"
import "modules/osd"
import "modules/clipboard"

ShellRoot {
    // Gemeinsame Einstellungen (~/.config/etude/settings/, siehe docs/settings.md)
    EtudeConfig { id: config }

    // Theme folgt den Einstellungen (Hell/Dunkel, Akzentfarbe)

    // kitty folgt der Transparenz: Datei schreiben, laufende kitty-Fenster neu laden
    Connections {
        target: config
        function onTransparencyChanged() { kittyTimer.restart() }
    }
    Timer {
        id: kittyTimer
        interval: 300
        running: true                        // einmal beim Start
        onTriggered: Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"${XDG_CONFIG_HOME:-$HOME/.config}/kitty\" && " +
            "printf 'background_opacity %s\\n' " + (config.transparency ? "0.82" : "1.0") +
            " > \"${XDG_CONFIG_HOME:-$HOME/.config}/kitty/etude-transparency.conf\" && pkill -USR1 -x kitty; true"])
    }

    // Verteiler für Tastenkürzel → die Leiste des fokussierten Monitors reagiert
    QtObject {
        id: shellBus
        signal toggleStartMenu(string monitor)
        signal toggleStartContext(string monitor)
    }

    // Von außen steuern, z. B. aus Hyprland:
    //   qs -p $ETUDE_HOME/shell ipc call startmenu toggle    (Super)
    //   qs -p $ETUDE_HOME/shell ipc call startmenu context   (Super+X)
    IpcHandler {
        target: "startmenu"
        function toggle(): void {
            shellBus.toggleStartMenu(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
        }
        function context(): void {
            shellBus.toggleStartContext(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
        }
    }

    // Automatisch sperren / Bildschirm aus / Energiesparmodus (IdleMonitor)
    Idle {
        settings: config
        onLockRequested: lockScreen.lock()
    }

    // Nachtlicht (hyprsunset) und "Identifizieren" für die Bildschirm-Einstellungen
    NightLight { settings: config }
    Identify { id: identifyOverlay }
    IpcHandler {
        target: "display"
        function identify(): void { identifyOverlay.show() }
    }

    // Benachrichtigungen: Dienst, Banner unten rechts, Center über der Uhr
    NotificationService { id: notifySvc; settings: config }
    NotificationPopups {
        service: notifySvc
        atBottom: config.barPosition !== "top"
        position: config.notifyPosition          // Einstellungen › Benachrichtigungen › Position
    }

    // Zwischenablage-Verlauf (Super+V)
    ClipboardHistory { atBottom: config.barPosition !== "top" }

    // OSD für Lautstärke, Helligkeit, Mikrofon (Pille über der Taskleiste)
    Osd { id: osdSvc; atBottom: config.barPosition !== "top" }

    // Benutzerkontensteuerung (eigener Polkit-Agent, wie Windows-UAC).
    // LazyLoader: fehlt Quickshell.Services.Polkit, läuft der Rest der Shell weiter.
    LazyLoader {
        active: true
        source: Qt.resolvedUrl("modules/polkit/Uac.qml")
    }

    // Sperrbildschirm (Super+L)
    Lock { id: lockScreen; wallpaper: config.lockActiveWallpaper; tint: config.lockTint }   // Personalisierung › Sperrbildschirm
    // Anmeldebildschirm (greetd) übernimmt automatisch dein Aussehen
    GreeterSync { config: config }

    // Hintergrundbild pro Monitor
    Variants {
        model: Quickshell.screens
        Background {
            required property var modelData
            screen: modelData
            source: config.activeWallpaper
            tint: config.wallpaperColor
        }
    }

    // Eine Taskleiste pro Monitor
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            bus: shellBus
            atBottom: config.barPosition !== "top"
            barLayout: config.barLayout
            pinnedApps: config.barPinned
            configSvc: config
            clock24: config.clock24
            clockSeconds: config.clockSeconds
            notifications: notifySvc
            osd: osdSvc
        }
    }
}
