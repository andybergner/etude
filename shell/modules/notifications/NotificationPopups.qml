// Banner in einer Ecke (Standard: unten rechts über der Taskleiste) auf dem Monitor mit Fokus.
// Wie shadcn/Sonner: höchstens 3 Banner, übereinander gestapelt – die neueste vorne, die beiden
// davor schauen nur mit der Kante dahinter hervor. Maus darüber fächert den Stapel auf und hält
// alle Timer an. Dringende bleiben stehen. Weitere Banner warten, bis vorne Platz wird.
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import Etude.Ui

PanelWindow {
    id: win

    property var service                    // NotificationService
    property bool atBottom: true            // Taskleiste unten → Banner unten rechts
    // Ecke: "auto" (rechts, an der Taskleiste) | "bottom-right" | "bottom-left" | "top-right" | "top-left"
    property string position: "auto"
    readonly property bool cornerBottom: position === "auto" ? atBottom : position.startsWith("bottom")
    readonly property bool cornerLeft: position.endsWith("left")

    readonly property int maxVisible: 3
    readonly property int peekStep: 10      // so weit schaut jeder hintere Banner hervor
    readonly property int gap: 8            // Abstand aufgefächert
    // Auffächern sofort beim Darüberfahren, Zuklappen erst kurz nach dem Verlassen – sonst flackert es,
    // wenn sich das Fenster beim Auf-/Zuklappen in der Größe ändert und die Maus kurz „draußen“ ist.
    property bool hoverLatched: false
    readonly property bool expanded: hoverLatched && stack.count > 1
    Timer { id: unhoverTimer; interval: 300; onTriggered: win.hoverLatched = false }

    // neueste zuerst, höchstens 3
    readonly property var shown: win.service.popups.slice().reverse().slice(0, maxVisible)

    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor
        const s = Quickshell.screens
        for (let i = 0; i < s.length; i++) if (m && s[i].name === m.name) return s[i]
        return s.length > 0 ? s[0] : null
    }

    // Höhen: zugeklappt = vorderster Banner + Kanten, aufgefächert = alle untereinander
    function natural(i) { const it = stack.itemAt(i); return it ? it.naturalHeight : 0 }
    readonly property real frontHeight: stack.count > 0 ? natural(0) : 0
    readonly property real expandedHeight: {
        let h = 0
        for (let i = 0; i < stack.count; i++) h += natural(i) + (i > 0 ? gap : 0)
        return h
    }
    readonly property real collapsedHeight: frontHeight + Math.max(0, stack.count - 1) * peekStep
    function offset(i) {                    // Abstand der Kante zur Ecke (aufgefächert)
        let d = 0
        for (let j = 0; j < i; j++) d += natural(j) + gap
        return d
    }

    screen: focusedScreen
    visible: service.popups.length > 0
    color: "transparent"
    anchors { right: !win.cornerLeft; left: win.cornerLeft; bottom: win.cornerBottom; top: !win.cornerBottom }
    margins { right: 12; left: 12; bottom: 12; top: 12 }
    implicitWidth: Theme.menuWidth
    // Feste Fenstergröße: Ändert sich die Größe einer Ebene, verschiebt Hyprland sie für ein paar
    // Frames (und animiert das sogar) – das war das Springen und Flackern beim Auf-/Zuklappen.
    // Das Fenster ist deshalb immer so hoch wie der größte Stapel sein kann; die leere Fläche ist
    // durchsichtig, und Klicks gehen dort durch (mask = nur der sichtbare Stapel).
    implicitHeight: screen ? Math.round(screen.height * 0.8) : 800
    // Normal: hält Abstand zur Taskleiste (deren exklusiver Bereich); selbst reserviert es nichts
    exclusionMode: ExclusionMode.Normal
    mask: Region { item: zoneItem }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "etude-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Item {
        id: area
        anchors.fill: parent
        // Maus zählt nur über dem sichtbaren Stapel (nicht über dem ganzen Fenster: das bleibt beim
        // Zuklappen kurz groß, sonst würde die Maus darüber den Stapel gleich wieder auffächern).
        // Der HoverHandler sitzt auf dem Elternelement, damit die Banner selbst ihren Hover behalten.
        HoverHandler { id: stackHover }
        readonly property real zoneHeight: win.expanded ? win.expandedHeight : win.collapsedHeight
        // sichtbarer Stapel – Eingabebereich des Fensters (mask)
        Item {
            id: zoneItem
            width: parent.width
            height: area.zoneHeight
            anchors.bottom: win.cornerBottom ? parent.bottom : undefined
            anchors.top: win.cornerBottom ? undefined : parent.top
        }
        readonly property bool inStack: stackHover.hovered
            && (win.cornerBottom ? stackHover.point.position.y >= height - zoneHeight
                                 : stackHover.point.position.y <= zoneHeight)
        onInStackChanged: Qt.callLater(() => {          // später: sonst Bindungsschleife über zoneHeight
            if (area.inStack) { unhoverTimer.stop(); win.hoverLatched = true }
            else unhoverTimer.restart()
        })

        Repeater {
            id: stack
            // ScriptModel behält vorhandene Banner (keine neue Animation, Timer laufen weiter)
            model: ScriptModel { values: win.shown }

            NotificationCard {
                id: card
                required property var modelData
                required property int index
                readonly property real naturalHeight: implicitHeight
                readonly property bool behind: !win.expanded && index > 0

                notif: modelData
                service: win.service
                banner: true
                peek: behind
                opaque: stack.count > 1
                width: area.width
                z: win.maxVisible - index
                time: win.service.timeOf(modelData)
                now: clock.date

                // hinten: so hoch wie der vorderste, etwas schmaler, nur die Kante sichtbar
                height: behind ? win.frontHeight : naturalHeight
                scale: behind ? 1 - 0.05 * index : 1
                transformOrigin: win.cornerBottom ? Item.Top : Item.Bottom
                // Abstand zur Ecke: zugeklappt nach Rang versetzt, aufgefächert untereinander.
                // An der Ecke verankert (nicht über y), damit eine Größenänderung des Fensters nichts verschiebt.
                property real edge: win.expanded ? win.offset(index) : index * win.peekStep
                Behavior on edge { enabled: card.ready; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                anchors.bottom: win.cornerBottom ? area.bottom : undefined
                anchors.top: win.cornerBottom ? undefined : area.top
                anchors.bottomMargin: edge
                anchors.topMargin: edge
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // Einblenden: vom Bildschirmrand hereinschieben
                property bool ready: false
                transform: Translate { id: shift; x: 0 }
                Component.onCompleted: { slideIn.start(); ready = true }
                ParallelAnimation {
                    id: slideIn
                    NumberAnimation { target: shift; property: "x"; from: win.cornerLeft ? -40 : 40; to: 0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160 }
                }

                // Anzeigedauer: wie von der App gewünscht, sonst 6 s; dringende bleiben.
                // Läuft nicht, solange die Maus über dem Stapel ist.
                readonly property int timeout: {
                    if (!modelData || modelData.urgency === NotificationUrgency.Critical) return 0
                    const t = modelData.expireTimeout
                    if (t > 0) return t < 1000 ? t * 1000 : t     // Sekunden oder Millisekunden
                    return 6000
                }
                Timer {
                    interval: card.timeout
                    running: card.timeout > 0 && !win.hoverLatched
                    onTriggered: {
                        const n = card.modelData
                        win.service.hidePopup(n)
                        if (n && n.transient) n.expire()       // flüchtige nicht im Verlauf behalten
                    }
                }
            }
        }
    }
}
