import QtQuick
import Quickshell
import Etude.Services
import Quickshell.Io

// Bildschirme: liest "hyprctl monitors all -j", ändert über HyprSettings
// (hl.monitor in etude-settings.lua) und fragt danach wie Windows nach:
// "Diese Anzeigeeinstellungen beibehalten?" – ohne Antwort geht es nach 15 s zurück.
Item {
    id: root

    required property var hypr            // HyprSettings.qml

    property var monitors: []             // [{ id, name, description, width, height, refresh, x, y, scale, transform, modes, disabled }]
    property string selected: ""          // Name des ausgewählten Bildschirms
    readonly property var current: monitors.find(m => m.name === selected) || monitors[0] || null

    // Bestätigung nach einer Änderung
    property var previous: null           // hypr.monitors vor der Änderung
    property int countdown: 0
    readonly property bool confirming: countdown > 0

    function refresh() { listProc.running = true }

    Process {
        id: listProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(this.text) } catch (e) { return }
                root.monitors = list.map(m => ({
                    id: m.id,
                    name: m.name,
                    description: (m.make && m.model ? m.make + " " + m.model : m.description) || m.name,
                    width: m.width, height: m.height,
                    refresh: m.refreshRate,
                    x: m.x, y: m.y,
                    scale: m.scale,
                    transform: m.transform || 0,
                    modes: (m.availableModes || []).map(s => s.replace(/Hz$/, "")),
                    disabled: !!m.disabled
                })).sort((a, b) => a.id - b.id)
                if (!root.monitors.some(m => m.name === root.selected) && root.monitors.length > 0)
                    root.selected = (root.monitors.find(m => !m.disabled) || root.monitors[0]).name
            }
        }
    }

    // Aktueller Zustand eines Bildschirms als hl.monitor-Werte
    function configOf(m) {
        return {
            mode: m.width + "x" + m.height + "@" + Number(m.refresh).toFixed(2),
            x: m.x, y: m.y, scale: m.scale, transform: m.transform, disabled: m.disabled
        }
    }

    // Änderung an einem Bildschirm anwenden: alle Bildschirme festschreiben
    // (sonst springen die anderen beim Neuladen evtl. an andere Positionen)
    function change(name, changes, needsConfirm) {
        const all = {}
        for (const m of monitors) all[m.name] = configOf(m)
        all[name] = Object.assign({}, all[name], changes)
        if (needsConfirm !== false && !confirming) previous = JSON.parse(JSON.stringify(hypr.monitors))
        hypr.setMonitors(all)
        if (needsConfirm !== false) countdown = 15
        refreshLater.restart()
    }

    function keep() { countdown = 0; previous = null }
    function revert() {
        countdown = 0
        if (previous !== null) hypr.setMonitors(previous)
        previous = null
        refreshLater.restart()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.countdown > 0
        onTriggered: if (--root.countdown <= 0) root.revert()
    }
    Timer { id: refreshLater; interval: 1200; onTriggered: root.refresh() }

    // Nummern auf den Bildschirmen anzeigen (macht die Shell)
    function identify() {
        Quickshell.execDetached(["qs", "-p", Paths.home + "/shell", "ipc", "call", "display", "identify"])
    }

    Component.onCompleted: refresh()
}
