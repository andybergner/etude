import QtQuick

// Kontextmenü aus Daten (shadcn: DropdownMenu / ContextMenu) – reines QtQuick.
//
// model: [
//   { label: "Terminal", icon: "…", shortcut: "Super Enter", exec: "kitty" },
//   { type: "separator" },
//   { type: "label", label: "System" },
//   { label: "Herunterfahren", icon: "…", variant: "destructive", submenu: [ ... ] },
//   { label: "Details", checked: true }      // Auswahl: Haken rechts
// ]
//
// Tastatur: ↑/↓ wählen, Enter ausführen, → Untermenü, ←/Esc zurück bzw. schließen.
FocusScope {
    id: root

    property var model: []
    property real menuWidth: 260
    property int currentIndex: -1
    property int openSubIndex: -1
    property bool submenuOnLeft: false

    signal triggered(var entry)              // Eintrag ohne Untermenü gewählt
    signal closeRequested()

    readonly property var items: model || []
    readonly property real subX: submenuOnLeft ? 0 : surface.width - 4

    implicitWidth: surface.width + (subLoader.item ? subLoader.item.implicitWidth - 4 : 0)
    implicitHeight: Math.max(surface.height, subLoader.item ? subLoader.y + subLoader.item.implicitHeight : 0)

    function isSelectable(i) {
        const e = items[i]
        return e && (e.type === undefined || e.type === "item") && !e.disabled
    }
    function move(step) {
        let i = currentIndex
        for (let n = 0; n < items.length; n++) {
            i = (i + step + items.length) % items.length
            if (isSelectable(i)) { currentIndex = i; return }
        }
    }
    function activate(i) {
        const e = items[i]
        if (!e || !isSelectable(i)) return
        if (e.submenu) { openSubIndex = i; Qt.callLater(() => { if (subLoader.item) { subLoader.item.currentIndex = 0; subLoader.item.forceActiveFocus() } }); return }
        root.triggered(e)
    }

    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)
    Keys.onReturnPressed: activate(currentIndex)
    Keys.onEnterPressed: activate(currentIndex)
    Keys.onRightPressed: if (items[currentIndex] && items[currentIndex].submenu) activate(currentIndex)
    Keys.onLeftPressed: root.closeRequested()
    Keys.onEscapePressed: root.closeRequested()

    Surface {
        id: surface
        x: root.submenuOnLeft && subLoader.item ? subLoader.item.implicitWidth - 4 : 0
        width: root.menuWidth
        height: col.implicitHeight + 8

        Column {
            id: col
            width: parent.width

            Repeater {
                id: rep
                model: root.items
                delegate: Loader {
                    id: row
                    required property var modelData
                    required property int index
                    width: col.width
                    sourceComponent: modelData.type === "separator" ? sepComp
                                   : modelData.type === "label" ? labelComp
                                   : itemComp

                    Component {
                        id: sepComp
                        MenuSeparator {}
                    }
                    Component {
                        id: labelComp
                        MenuLabel { label: row.modelData.label || "" }
                    }
                    Component {
                        id: itemComp
                        MenuItem {
                            icon: row.modelData.icon || ""
                            text: row.modelData.label || ""
                            shortcut: row.modelData.shortcut || ""
                            variant: row.modelData.variant || "default"
                            disabled: !!row.modelData.disabled
                            checkable: row.modelData.checked !== undefined
                            checked: !!row.modelData.checked
                            hasSubmenu: !!row.modelData.submenu
                            highlighted: root.currentIndex === row.index || root.openSubIndex === row.index
                            onHoveredChanged2: (h) => {
                                if (!h) return
                                root.currentIndex = row.index
                                root.openSubIndex = row.modelData.submenu ? row.index : -1
                                root.forceActiveFocus()
                            }
                            onClicked: root.activate(row.index)
                        }
                    }
                }
            }
        }
    }

    // Untermenü rechts (bzw. links) neben dem Eintrag
    Loader {
        id: subLoader
        active: root.openSubIndex >= 0 && !!(root.items[root.openSubIndex] || {}).submenu
        x: root.submenuOnLeft ? 0 : surface.width - 4
        // auf Höhe des Eintrags, aber nie unter das Hauptmenü hinaus (Leiste unten)
        y: {
            if (!active || !item) return 0
            const it = rep.itemAt(root.openSubIndex)
            const want = it ? it.y + surface.padding - 4 : 0
            return Math.max(0, Math.min(want, surface.height - item.implicitHeight))
        }
        // Rekursion über die Datei statt über den Typ (QML erlaubt keinen Typ in sich selbst)
        source: active ? Qt.resolvedUrl("ContextMenu.qml") : ""
        onLoaded: {
            item.model = Qt.binding(() => root.items[root.openSubIndex] ? root.items[root.openSubIndex].submenu : [])
            item.menuWidth = 220
            item.triggered.connect((e) => root.triggered(e))
            item.closeRequested.connect(() => { root.openSubIndex = -1; root.forceActiveFocus() })
        }
    }
}
