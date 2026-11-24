// Kalender über der Uhr. Eigene Ebene: Klick daneben oder Esc schließt.
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui
import "../bar/Place.js" as Place

PanelWindow {
    id: win

    property Item anchorItem          // Uhr in der Leiste
    property real barHeight: 48
    property bool atBottom: true
    property date now: new Date()
    property real anchorRight: -1     // rechte Kante der Uhr auf dem Bildschirm
    property real anchorLeft: -1

    function toggle() { visible ? close() : open() }
    function open() {
        // rechte Kante der Uhr merken (die Fensterbreite steht erst nach dem Öffnen fest)
        anchorRight = anchorItem ? anchorItem.mapToItem(null, anchorItem.width, 0).x : -1
        anchorLeft = anchorItem ? anchorItem.mapToItem(null, 0, 0).x : -1
        panel.reset()
        visible = true
        panel.forceActiveFocus()
    }
    function close() { visible = false }

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
    WlrLayershell.namespace: "etude-calendar"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: win.close() }

    FocusRoot {                              // Tastatur wie bei Windows (Pfeile, Enter, Fokus-Ring)
        anchors.fill: parent
    CalendarContent {
        id: panel
        now: win.now
        // je nach Lage der Uhr: links, mittig oder am rechten Rand
        x: Place.x(win.anchorLeft, win.anchorRight, width, win.width)
        y: win.atBottom ? win.height - win.barHeight - height - 8 : win.barHeight + 8
        onCloseRequested: win.close()
        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
    }
    }
}
