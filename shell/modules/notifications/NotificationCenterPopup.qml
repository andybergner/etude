// Benachrichtigungscenter als eigenes Fenster rechts über der Taskleiste.
// Öffnet über die Glocke in der Leiste oder Super+N. Klick daneben oder Esc schließt.
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui
import "../bar/Place.js" as Place

PanelWindow {
    id: win

    property var service                  // NotificationService
    property real barHeight: 48
    property bool atBottom: true
    property Item anchorItem               // Glocke in der Leiste
    property real anchorLeft: -1
    property real anchorRight: -1

    function toggle() { visible ? close() : open() }
    function open() {
        anchorLeft = anchorItem ? anchorItem.mapToItem(null, 0, 0).x : -1
        anchorRight = anchorItem ? anchorItem.mapToItem(null, anchorItem.width, 0).x : -1
        visible = true
        panel.forceActiveFocus()
    }
    function close() { visible = false }

    // offen → keine Banner
    onVisibleChanged: if (service) service.centerOpen = visible

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Die Leiste bleibt klickbar: Klicks dort gehen an die Leiste, nicht an die Klickfläche zum Schließen.
    // So öffnet ein Klick auf einen anderen Button sofort dessen Menü.
    mask: Region {
        x: 0
        y: win.atBottom ? 0 : win.barHeight
        width: win.width
        height: Math.max(0, win.height - win.barHeight)
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "etude-notifications-center"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    SystemClock { id: clock; precision: SystemClock.Minutes }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: win.close() }

    FocusRoot {                              // Tastatur wie bei Windows (Pfeile, Enter, Fokus-Ring)
        anchors.fill: parent
    NotificationCenter {
        id: panel
        service: win.service
        now: clock.date
        focus: true
        Keys.onEscapePressed: win.close()
        // rechts, über bzw. unter der Leiste wie die anderen Menüs
        maxHeight: win.height - win.barHeight - 16
        x: Place.x(win.anchorLeft, win.anchorRight, width, win.width)
        y: win.atBottom ? win.height - win.barHeight - height - 8 : win.barHeight + 8
        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
    }
    }
}
