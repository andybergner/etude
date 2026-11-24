import QtQuick

// Tastatur-Wurzel eines Fensters – macht für alles darin, was fokussierbar ist, das, was
// der Browser bei HTML macht:
//   • Pfeiltasten springen räumlich zum nächsten Element (FocusNav), auch bei Buttons aus
//     QtQuick.Controls oder eigenen Elementen mit activeFocusOnTab: true (= tabindex="0")
//   • Enter/Leertaste lösen Elemente mit einem clicked()-Signal aus
//   • fokussierte Elemente werden in Flickables ins Bild gescrollt (auch per Tab)
//   • Elemente ohne eigenen Fokus-Ring bekommen einen
// Etude.Ui-Fenster (AppWindow) bringen FocusRoot schon mit; sonst einfach außen herum legen:
//   FocusRoot { anchors.fill: parent; MeinInhalt { anchors.fill: parent; focus: true } }
FocusScope {
    id: root
    focus: true

    readonly property Item focusItem: Window.activeFocusItem
    onFocusItemChanged: {
        if (focusItem && focusItem !== root) FocusNav.reveal(focusItem)
        ring.update()
    }

    // Tasten, die kein Element selbst behandelt hat, landen hier
    Keys.onPressed: (e) => {
        const it = focusItem
        const plain = !(e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
        const arrow = e.key === Qt.Key_Up || e.key === Qt.Key_Down || e.key === Qt.Key_Left || e.key === Qt.Key_Right
        if (!it || it === root) {                       // noch nichts fokussiert: erstes Element
            if (plain && arrow) e.accepted = FocusNav.first(root)
            return
        }
        if (arrow) { FocusNav.key(it, e); return }
        if (plain && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space))
            e.accepted = FocusNav.activate(it)
    }

    // Fokus-Ring für Elemente ohne eigenen (z. B. Buttons aus QtQuick.Controls, eigene Elemente)
    Rectangle {
        id: ring
        z: 100000
        visible: false
        color: "transparent"
        radius: Theme.radiusMd
        border.width: 2
        border.color: Theme.ring
        function update() {
            const it = root.focusItem
            visible = FocusNav.needsRing(it)
            if (!visible) return
            const p = it.mapToItem(root, 0, 0)
            x = p.x - 2; y = p.y - 2; width = it.width + 4; height = it.height + 4
        }
    }
    FrameAnimation { running: ring.visible; onTriggered: ring.update() }   // folgt beim Scrollen
}
