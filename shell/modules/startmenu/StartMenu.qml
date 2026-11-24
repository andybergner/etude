// Startmenü (Linksklick auf den Start-Button).
// Eigene Ebene über dem Bildschirm: Klick daneben oder Esc schließt.
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui
import Etude.Services
import "../bar/Place.js" as Place

PanelWindow {
    id: win
    property Translations tr: Translations { domain: "startmenu" }   // Texte dieses Moduls

    property Item anchorItem
    property real barHeight: 48
    property bool atBottom: true

    function toggle() { visible ? close() : open() }
    function open() {
        // Start links → linksbündig, Start in der Mitte → mittig (wie Windows 11)
        const l = anchorItem ? anchorItem.mapToItem(null, 0, 0).x : 0
        const r = anchorItem ? l + anchorItem.width : 0
        menu.x = anchorItem ? Place.x(l, r, menu.width, win.screen ? win.screen.width : 1920) : 8
        menu.reset()
        visible = true
        menu.focusSearch()
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
    WlrLayershell.namespace: "etude-startmenu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Apps { id: apps }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: win.close()
    }

    FocusRoot {                              // Tastatur wie bei Windows (Pfeile, Enter, Fokus-Ring)
        anchors.fill: parent
        StartMenuContent {
            id: menu
            y: win.atBottom ? win.height - win.barHeight - height - 8 : win.barHeight + 8
            userName: Quickshell.env("USER") || win.tr.t("startmenu.user")
            apps: apps.list
            onLaunch: (id) => { win.close(); apps.launch(id) }
            onCloseRequested: win.close()
            onPowerAction: (entry) => {
                win.close()
                if (entry.exec) Quickshell.execDetached(["sh", "-c", entry.exec])
            }

            // Klicks im Menü nicht an die Fläche dahinter geben
            MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
        }
    }
}
