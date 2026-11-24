// Kontextmenü am Start-Button (Rechtsklick) – auch für den Rechtsklick auf die Taskleiste
// (eigene entries, Position an der Maus über atX).
// Eigene Ebene über dem ganzen Bildschirm: Das Menü sitzt über dem Start-Button,
// ein Klick irgendwo daneben (oder Esc) schließt es.
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui
import "StartContextEntries.js" as Entries

PanelWindow {
    id: win
    property Translations tr: Translations { domain: "startmenu" }   // Texte dieses Moduls

    property Item anchorItem           // Start-Button in der Leiste
    property real barHeight: 48
    property bool atBottom: true       // Leiste unten -> Menü darüber
    property var entries: Entries.entries(win.tr)
    property real atX: -1              // >= 0: Menü an dieser x-Position (z. B. Maus) statt am Start-Button

    function toggle() { visible ? close() : open() }
    function open() {
        // Position des Start-Buttons auf dem Bildschirm
        const sw = screen ? screen.width : 1920
        const want = atX >= 0 ? atX - 8 : (anchorItem ? anchorItem.mapToItem(null, 0, 0).x : 8)
        menu.x = Math.max(8, Math.min(sw - menu.menuWidth - 8, want))
        menu.currentIndex = -1
        menu.openSubIndex = -1
        visible = true
        menu.forceActiveFocus()
    }
    function close() { visible = false }

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore          // über die Leiste hinweg

    // Die Leiste bleibt klickbar: Klicks dort gehen an die Leiste, nicht an die Klickfläche zum Schließen.
    // So öffnet ein Klick auf einen anderen Button sofort dessen Menü.
    mask: Region {
        x: 0
        y: win.atBottom ? 0 : win.barHeight
        width: win.width
        height: Math.max(0, win.height - win.barHeight)
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "etude-menu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Klick neben das Menü schließt es
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: win.close()
    }

    ContextMenu {
        id: menu
        y: win.atBottom ? win.height - win.barHeight - implicitHeight - 4
                        : win.barHeight + 4
        model: win.entries
        focus: true
        onTriggered: (entry) => {
            win.close()
            if (typeof entry.run === "function") entry.run()          // eigene Aktion (z. B. Taskleiste)
            else if (entry.exec) Quickshell.execDetached(["sh", "-c", entry.exec])
        }
        onCloseRequested: win.close()

        // Klicks auf das Menü selbst nicht an die Fläche dahinter weitergeben
        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
    }
}
