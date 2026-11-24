import QtQuick
import Quickshell

// App-Fenster: FloatingWindow mit Tastatur-Wurzel (FocusRoot) – Pfeiltasten, Enter und
// Fokus-Ring funktionieren damit für alles im Fenster, ohne weiteren Code.
//   AppWindow { title: "…"; MeinInhalt { anchors.fill: parent; focus: true } }
FloatingWindow {
    id: win
    default property alias content: focusRoot.data

    FocusRoot {
        id: focusRoot
        anchors.fill: parent
    }
}
