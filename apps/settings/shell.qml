//@ pragma AppId com.etude.settings
// Etude Einstellungen – eigenes Fenster, eigener Prozess
// Start:  etude-settings [seite]     z. B. etude-settings sound
// Läuft schon eine Instanz, öffnet etude-settings nur die Seite (IPC).
import Quickshell
import Quickshell.Io
import QtQuick
import Etude.Ui
import Etude.Services

ShellRoot {
    id: shellRoot

    // Eindeutige App-ID (reverse DNS). Wird für Startmenü-Eintrag, Icon, PID-Datei
    // und später als Wayland app_id verwendet – unabhängig von der Sprache des Titels.
    readonly property string appId: "com.etude.settings"

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/etude"

    // ---- Daten (dieselben Dienste wie die Leiste) ----
    Network { id: networkSvc }
    EtudeConfig { id: configSvc }

    // Theme folgt den Einstellungen (Hell/Dunkel, Akzentfarbe)
    Audio { id: audioSvc }
    HyprSettings { id: hyprSvc }
    TimeDate { id: timedateSvc }
    Storage { id: storageSvc }
    Battery { id: batterySvc }
    PowerProfile { id: powerSvc }
    Bluetooth { id: bluetoothSvc }
    Brightness { id: brightnessSvc }
    Account { id: accountSvc }
    Displays { id: displaysSvc; hypr: hyprSvc }
    AppManager { id: appsSvc }
    Privacy { id: privacySvc }
    Updates { id: updatesSvc }

    FileView { id: hostnameFile; path: "/etc/hostname"; watchChanges: true; onFileChanged: reload() }
    FileView { id: modelFile;    path: "/sys/class/dmi/id/product_name" }
    FileView { id: vendorFile;   path: "/sys/class/dmi/id/sys_vendor" }

    // Voller Name aus /etc/passwd (GECOS), sonst der Benutzername
    property string realName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: shellRoot.realName = this.text.trim() }
    }

    AppWindow {                      // FloatingWindow + Tastatur-Wurzel (Etude.Ui)
        id: win
        title: content.tr.t("settings.settings")   // erkannt wird die App über appId
        implicitWidth: 1120
        implicitHeight: 740
        color: "transparent"
        visible: true

        // Fenster zu = App beenden
        onVisibleChanged: if (!visible) Qt.quit()
        // Rückmeldungen (Konto angelegt, Kennwort geändert …) als Benachrichtigung von „Einstellungen“
        Component.onCompleted: { Notify.app = title; Notify.icon = "com.etude.settings" }

        SettingsContent {
            id: content
            anchors.fill: parent
            focus: true
            initialPage: Quickshell.env("ETUDE_SETTINGS_PAGE") || "system"
            userName: accountSvc.displayName
            avatar: accountSvc.hasFace ? "file://" + accountSvc.facePath + "#" + accountSvc.faceVersion : ""
            hyprLayout: hyprSvc.layout
            audio: audioSvc
            network: networkSvc
            config: configSvc
            timedate: timedateSvc
            hypr: hyprSvc
            storage: storageSvc
            battery: batterySvc
            power: powerSvc
            bluetooth: bluetoothSvc
            displays: displaysSvc
            brightness: brightnessSvc
            account: accountSvc
            apps: appsSvc
            privacy: privacySvc
            updates: updatesSvc
            onSetLayout: (l) => hyprSvc.setLayout(l)
            device: ({
                hostname: hostnameFile.text().trim(),
                model: [vendorFile.text().trim(), modelFile.text().trim()].filter(s => s && s !== "To Be Filled By O.E.M.").join(" "),
                wallpaper: configSvc.activeWallpaper ? "file://" + configSvc.activeWallpaper : "",
                network: networkSvc.kind === "ethernet" ? content.tr.t("device.wiredConnected")
                       : networkSvc.kind === "wifi" ? (networkSvc.ssid || content.tr.t("device.wifiConnected")) : "",
                networkIcon: String.fromCodePoint(networkSvc.kind === "ethernet" ? 0xF0200
                                               : networkSvc.kind === "wifi" ? 0xF05A9 : 0xF0A8E),
                battery: batterySvc.present ? content.tr.t(batterySvc.charging ? "device.batteryCharging" : "device.battery").arg(batterySvc.level) : ""
            })
        }
    }

    // Weitere Aufrufe von etude-settings landen hier
    IpcHandler {
        target: "settings"
        function open(page: string): void { content.open(page) }
    }
}
