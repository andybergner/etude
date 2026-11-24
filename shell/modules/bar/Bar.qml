// Taskleiste: Fenster (Quickshell) + echte Daten.
// Das Aussehen steckt komplett in BarContent.qml.
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Etude.Services
import Etude.Ui
import "../startmenu"
import "../calendar"
import "../menus"
import "../notifications"

PanelWindow {
    id: bar
    property Translations tr: Translations { domain: "bar" }   // Texte dieses Moduls

    property QtObject bus                // aus shell.qml (Tastenkürzel per IPC)

    // Position: unten wie bei Windows (aus den Einstellungen)
    property bool atBottom: true
    property var barLayout                  // Aufbau (EtudeConfig.barLayout)
    property var pinnedApps: []             // angeheftete Apps (EtudeConfig.barPinned)
    property var configSvc                  // EtudeConfig (zum Anheften/Lösen)
    property bool clock24: true
    property bool clockSeconds: false
    property var notifications              // NotificationService aus shell.qml
    property var osd                        // Osd aus shell.qml

    anchors {
        left: true
        right: true
        bottom: bar.atBottom
        top: !bar.atBottom
    }
    implicitHeight: content.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "etude-bar"

    // ---- Daten ----
    Network { id: network }
    Audio { id: audio }
    Battery { id: battery }
    Bluetooth { id: bluetooth }
    Brightness { id: brightness }
    SystemClock { id: clock; precision: bar.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    StartMenu {
        id: startMenu
        screen: bar.screen
        anchorItem: content.startButton
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
    }

    // SUPER+Space: nur das Startmenü auf dem fokussierten Monitor
    Connections {
        target: bar.bus
        function onToggleStartMenu(monitor) {
            if (!monitor || !bar.screen || monitor === bar.screen.name) { bar.only(startMenu); startMenu.toggle() }
        }
        function onToggleStartContext(monitor) {
            if (!monitor || !bar.screen || monitor === bar.screen.name) { bar.only(startContext); startContext.toggle() }
        }
    }

    // Nur ein Fenster der Leiste gleichzeitig: beim Öffnen die anderen schließen
    function only(keep) {
        if (keep !== startMenu && startMenu.visible) startMenu.close()
        if (keep !== startContext && startContext.visible) startContext.close()
        if (keep !== menus && menus.visible) menus.close()
        if (keep !== calendar && calendar.visible) calendar.close()
        if (keep !== notifCenter && notifCenter.visible) notifCenter.close()
        if (keep !== barContext && barContext.visible) barContext.close()
        if (keep !== appMenu && appMenu.visible) appMenu.close()
        tooltip.dismiss()
        windowList.dismiss()
    }

    // Rechtsklick auf die Taskleiste (wie Windows)
    StartContextMenu {
        id: barContext
        screen: bar.screen
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
        entries: [
            { label: bar.tr.t("bar.taskManager"), shortcut: bar.tr.t("bar.taskManagerShortcut"), exec: "etude-taskmanager" },
            { type: "separator" },
            { label: bar.tr.t("bar.taskbarSettings"), exec: "etude-settings personalization/taskbar" }
        ]
    }

    // Tooltips über Netzwerk, Sound, Akku, Glocke, Uhr …
    function batteryTime(s) {
        if (s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return h > 0 ? I18n.t("common.durationHoursMinutes").arg(h).arg(m) : I18n.t("common.durationMinutes").arg(m)
    }
    function tipFor(b) {
        if (!b) return ""
        if (b.tipText !== undefined) return b.tipText               // Apps: Name + Fenstertitel
        if (b === content.startButton) return tr.t("bar.start")
        if (b === content.micButton) {
            const names = [...new Set(audio.recording.map(r => r.name))]
            return tr.t("bar.micInUse").arg(names.join(", "))
        }
        if (b === content.networkButton) {
            const c = network.connectivity
            const net = c === "full" ? tr.t("bar.internet")
                      : c === "portal" ? tr.t("bar.signInRequired")
                      : (c === "limited" || c === "none") ? tr.t("bar.noInternet") : ""
            if (network.kind === "wifi") return tr.t("bar.wifi").arg(network.ssid || network.info.name || tr.t("bar.connected")) + (net ? "\n" + net : "")
            if (network.kind === "ethernet") return tr.t("bar.ethernet").arg(network.info.name || tr.t("bar.wiredConnection")) + (net ? "\n" + net : "")
            return network.hasWifi && !network.wifiEnabled ? tr.t("bar.wifiOff") : tr.t("bar.notConnected")
        }
        if (b === content.bluetoothButton)
            return !bluetooth.enabled ? tr.t("bar.bluetoothOff") : bluetooth.device !== "" ? tr.t("bar.bluetoothDevice").arg(bluetooth.device) : tr.t("bar.bluetoothOn")
        if (b === content.volumeButton) {
            const s = audio.sinks.find(x => x.active)
            const name = s ? s.name : tr.t("bar.speakers")
            return audio.muted ? tr.t("bar.volumeMuted").arg(name) : tr.t("bar.volume").arg(name).arg(Math.round(audio.volume * 100))
        }
        if (b === content.batteryButton) {
            const t = bar.batteryTime(battery.secondsLeft)
            return tr.t(battery.charging ? "bar.batteryCharging" : "bar.battery").arg(battery.level) +
                   (t ? "\n" + tr.t(battery.charging ? "bar.fullIn" : "bar.remaining").arg(t) : "")
        }
        if (b === content.bellButton) {
            const n = bar.notifications ? bar.notifications.count : 0
            const dnd = bar.notifications && bar.notifications.dnd
            return (n === 0 ? tr.t("bar.noNotifications") : tr.tn("bar.notifications", n).arg(n)) +
                   (dnd ? "\n" + tr.t("bar.dndOn") : "")
        }
        if (b === content.clockButton)
            return clock.date.toLocaleDateString(I18n.locale, Locale.LongFormat)
        return ""
    }

    BarTooltip {
        id: tooltip
        screen: bar.screen
        atBottom: bar.atBottom
        target: content.hoveredButton
        text: bar.tipFor(content.hoveredButton)
        suppressed: startMenu.visible || startContext.visible || barContext.visible || appMenu.visible || menus.visible || calendar.visible || notifCenter.visible
        onTargetChanged: if (target === content.networkButton) network.refresh()
    }

    // Fensterliste beim Hover über einer App mit mehreren Fenstern
    WindowList {
        id: windowList
        screen: bar.screen
        atBottom: bar.atBottom
        apps: content.appsItem
        target: content.appsItem.hoveredItem
        suppressed: tooltip.suppressed
    }

    PowerProfile { id: power }
    Media { id: media }

    // Menüs für Netzwerk, Bluetooth, Lautsprecher, Akku
    BarPopup {
        id: menus
        screen: bar.screen
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
        network: network
        audio: audio
        battery: battery
        bluetooth: bluetooth
        brightness: brightness
        power: power
        media: media
        onOpenSettings: (page) => Quickshell.execDetached(["etude-settings", page])
    }

    CalendarPopup {
        id: calendar
        screen: bar.screen
        anchorItem: content.clockButton
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
        now: clock.date
    }

    NotificationCenterPopup {
        id: notifCenter
        screen: bar.screen
        anchorItem: content.bellButton
        service: bar.notifications
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
    }

    // ipc call notifications center → Center auf dem fokussierten Monitor
    Connections {
        target: bar.notifications
        function onCenterRequested() {
            const m = Hyprland.focusedMonitor
            if (!m || !bar.screen || m.name === bar.screen.name) { bar.only(notifCenter); notifCenter.toggle() }
        }
    }

    StartContextMenu {
        id: startContext
        screen: bar.screen
        anchorItem: content.startButton
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
    }

    // ---- Rechtsklick auf eine App in der Leiste ----
    StartContextMenu {
        id: appMenu
        screen: bar.screen
        barHeight: bar.implicitHeight
        atBottom: bar.atBottom
        entries: []
    }
    function showAppMenu(app, button) {
        const pinned = (bar.pinnedApps || []).indexOf(app.id) >= 0
        // läuft die App schon: „Neues Fenster“ (Aktion "new-window" der .desktop-Datei, sonst normal starten),
        // dazu die übrigen Aktionen der .desktop-Datei (wie die Sprungliste bei Windows)
        const acts = app.entry && app.entry.actions ? app.entry.actions : []
        const nw = acts.find(a => a.id === "new-window")
        const e = app.windows.length
            ? [{ label: tr.t("bar.newWindow"), run: () => nw ? nw.execute() : content.appsItem.launch(app) }]
            : [{ label: app.name, run: () => content.appsItem.launch(app) }]
        for (const a of acts) if (a !== nw) e.push({ label: a.name, run: () => a.execute() })
        if (app.id) e.push({ type: "separator" },
            pinned ? { label: tr.t("bar.unpin"), run: () => bar.configSvc.set("barPinned", bar.pinnedApps.filter(x => x !== app.id)) }
                   : { label: tr.t("bar.pin"), run: () => bar.configSvc.set("barPinned", (bar.pinnedApps || []).concat([app.id])) })
        if (app.windows.length) e.push({ type: "separator" },
            { label: tr.t(app.windows.length > 1 ? "bar.closeAllWindows" : "bar.closeWindow"), variant: "destructive",
              run: () => content.appsItem.closeWindows(app) })
        const open = appMenu.visible
        bar.only(null)
        if (open) return
        appMenu.entries = e
        appMenu.atX = button.mapToItem(null, 0, 0).x
        appMenu.open()
    }

    // Freie Stelle der Leiste: Linksklick schließt offene Menüs, Rechtsklick öffnet das Kontextmenü
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: (m) => {
            if (m.button === Qt.RightButton) {
                const open = barContext.visible
                bar.only(null)
                if (!open) { barContext.atX = m.x; barContext.open() }
            } else bar.only(null)
        }
    }

    BarContent {
        id: content
        anchors.fill: parent
        atBottom: bar.atBottom
        barLayout: bar.barLayout
        pinnedApps: bar.pinnedApps
        onAppMenuRequested: (app, button) => bar.showAppMenu(app, button)
        clock24: bar.clock24
        clockSeconds: bar.clockSeconds

        activeWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        netKind: network.kind
        netSignal: network.signal
        wifiEnabled: network.wifiEnabled
        volume: audio.volume
        muted: audio.muted
        hasBattery: battery.present
        batteryLevel: battery.level
        charging: battery.charging
        now: clock.date
        notifCount: bar.notifications ? bar.notifications.count : 0
        dnd: bar.notifications ? bar.notifications.dnd : false
        micApps: audio.recording
        onMicClicked: { bar.only(null); menus.openSettings("privacy/microphone") }

        // Hyprland 0.55: dispatch nimmt einen Lua-Ausdruck
        onWorkspaceClicked: (id) => { bar.only(null); Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }
        onVolumeScrolled: (d) => { audio.change(d * 0.05); if (bar.osd) bar.osd.show("volume") }

        // Kommen später: Startmenü, Schnelleinstellungen, Kalender
        onStartClicked: { bar.only(startMenu); startMenu.toggle() }
        onStartRightClicked: { bar.only(startContext); startContext.toggle() }
        btPresent: bluetooth.present
        btEnabled: bluetooth.enabled
        btConnected: bluetooth.device !== ""

        onNetworkClicked: { bar.only(menus); menus.toggle("network", content.networkButton) }
        onBluetoothClicked: { bar.only(menus); menus.toggle("bluetooth", content.bluetoothButton) }
        onVolumeClicked: { bar.only(menus); menus.toggle("sound", content.volumeButton) }
        onBatteryClicked: { bar.only(menus); menus.toggle("battery", content.batteryButton) }
        onClockClicked: { bar.only(calendar); calendar.toggle() }
        onNotificationsClicked: { bar.only(notifCenter); notifCenter.toggle() }
    }
}
