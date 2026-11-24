import QtQuick
import Etude.Ui
import "DropUtil.js" as DropUtil

// Tabs wie im Windows-11-Explorer: Icon, Name, Schließen (×), „+“ für einen neuen Tab.
// Mittlere Maustaste schließt. Tabs lassen sich mit der Maus verschieben (die anderen rücken nach).
// Beim Darüberziehen von Dateien wechselt der Tab nach kurzer Zeit,
// Ablegen auf einem Tab kopiert/verschiebt in dessen Ordner.
Item {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    property var tabs: []                 // [{ label, loc, icon }]
    property int current: 0
    signal activated(int index)
    signal closeRequested(int index)
    signal newRequested()
    signal dropped(int index, var paths, bool copy)
    signal moved(int from, int to)

    // ---- Tabs verschieben ----
    property int dragFrom: -1             // gezogener Tab
    property real dragOffset: 0           // Mausweg seit dem Drücken
    property bool committing: false       // beim Loslassen: ohne Animation an die neue Stelle
    readonly property int dragTo: dragFrom < 0 ? -1
        : Math.max(0, Math.min(tabs.length - 1, dragFrom + Math.round(dragOffset / (tabWidth + 2))))
    // Verschiebung der übrigen Tabs, damit eine Lücke an der Zielstelle entsteht
    function shiftFor(i) {
        if (dragFrom < 0 || i === dragFrom) return 0
        if (dragTo > dragFrom && i > dragFrom && i <= dragTo) return -(tabWidth + 2)
        if (dragTo < dragFrom && i < dragFrom && i >= dragTo) return tabWidth + 2
        return 0
    }

    // Loslassen: erst den Zustand zurücksetzen, dann umsortieren. Läuft im Kontext der Leiste,
    // weil das Umsortieren die Tabs (samt der MouseArea, die gerade loslässt) neu aufbaut.
    function commitDrag() {
        if (dragFrom < 0) return
        const f = dragFrom, t = dragTo
        committing = true                 // ohne Animation an die neue Stelle
        dragFrom = -1
        dragOffset = 0
        if (t !== f) moved(f, t)
        commitReset.restart()
    }
    Timer { id: commitReset; interval: 0; onTriggered: root.committing = false }

    implicitHeight: 40

    readonly property real tabWidth: Math.max(120, Math.min(220, (width - 56) / Math.max(1, tabs.length)))

    // Der aktive Tab hat keine eigene Füllung: dort ist der Streifen ausgespart, es scheint die
    // Fensterfläche durch – genau wie bei Navigations- und Befehlsleiste darunter (wie Windows 11).

    // Streifen in der Farbe der Seitenleiste – unter dem aktiven Tab ausgespart, damit dessen Farbe
    // (auch bei Transparenz) genau der Navigationsleiste entspricht
    readonly property color stripColor: Theme.alpha(Theme.sidebar, Theme.glass)
    readonly property real tabTop: height - 34
    readonly property real activeX: strip.x + root.current * (tabWidth + 2) + (dragFrom === current ? dragOffset : 0)
    Rectangle { x: 0; y: 0; width: parent.width; height: root.tabTop; color: root.stripColor }
    Rectangle { x: 0; y: root.tabTop; width: Math.max(0, root.activeX); height: parent.height - root.tabTop; color: root.stripColor }
    Rectangle {
        x: root.activeX + root.tabWidth
        y: root.tabTop
        width: Math.max(0, parent.width - x)
        height: parent.height - root.tabTop
        color: root.stripColor
    }
    // Trennlinie zur Navigationsleiste (nicht unter dem aktiven Tab)
    Rectangle { x: 0; anchors.bottom: parent.bottom; width: Math.max(0, root.activeX); height: 1; color: Theme.border }
    Rectangle { x: root.activeX + root.tabWidth; anchors.bottom: parent.bottom; width: Math.max(0, parent.width - x); height: 1; color: Theme.border }

    Row {
        id: strip
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.bottom: parent.bottom
        spacing: 2

        Repeater {
            model: root.tabs
            Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool active: index === root.current
                width: root.tabWidth
                height: 34
                readonly property bool dragged: root.dragFrom === index
                z: dragged ? 10 : 0
                transform: Translate {
                    x: tab.dragged ? root.dragOffset : root.shiftFor(tab.index)
                    Behavior on x { enabled: !tab.dragged && !root.committing; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                opacity: dragged ? 0.9 : 1

                // inaktiv: Hover/Ablegen-Fläche
                Rectangle {
                    visible: !tab.active
                    anchors.fill: parent
                    topLeftRadius: Theme.radiusMd
                    topRightRadius: Theme.radiusMd
                    color: tabDrop.containsDrag ? Theme.alpha(Theme.primary, 0.18) : "transparent"
                    HoverLayer { shown: tabMouse.containsMouse; level: 0.6; radius: Theme.radiusMd }
                }
                // aktiv: nur Rahmen oben und an den Seiten (unten offen, geht in die Leiste darunter über)
                Item {
                    visible: tab.active
                    anchors.fill: parent
                    anchors.bottomMargin: -1
                    clip: true
                    Rectangle {
                        width: parent.width
                        height: parent.height + Theme.radiusMd + 2
                        radius: Theme.radiusMd
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.border
                    }
                }
                Text {
                    id: tabIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(tab.modelData.icon)
                    color: tab.active ? Theme.primary : Theme.mutedForeground
                    font.family: Theme.fontIcon; font.pixelSize: 15
                }
                Text {
                    anchors.left: tabIcon.right
                    anchors.leftMargin: 8
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: tab.modelData.label
                    color: tab.active ? Theme.foreground : Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 13
                    font.weight: tab.active ? Font.Medium : Font.Normal
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: root.dragFrom >= 0 ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    property real startX: 0
                    onPressed: (e) => {
                        if (e.button !== Qt.LeftButton) return
                        startX = mapToItem(root, e.x, 0).x
                        root.activated(tab.index)
                    }
                    onPositionChanged: (e) => {
                        if (!(e.buttons & Qt.LeftButton) || root.tabs.length < 2) return
                        const d = mapToItem(root, e.x, 0).x - startX
                        if (root.dragFrom < 0 && Math.abs(d) < 8) return
                        root.dragFrom = tab.index
                        // nicht über die Leiste hinaus ziehen
                        const minD = -tab.index * (root.tabWidth + 2)
                        const maxD = (root.tabs.length - 1 - tab.index) * (root.tabWidth + 2)
                        root.dragOffset = Math.max(minD, Math.min(maxD, d))
                    }
                    onReleased: root.commitDrag()
                    onCanceled: { root.dragFrom = -1; root.dragOffset = 0 }
                    onClicked: (e) => { if (e.button === Qt.MiddleButton) root.closeRequested(tab.index) }
                }
                Button {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "ghost"
                    size: "icon-xs"
                    iconStart: String.fromCodePoint(0xF0156)
                    opacity: tab.active || tabMouse.containsMouse || hovered ? 1 : 0
                    onClicked: root.closeRequested(tab.index)
                }

                // Dateien darüberziehen: nach 600 ms zum Tab wechseln, Ablegen = in dessen Ordner
                DropArea {
                    id: tabDrop
                    anchors.fill: parent
                    keys: ["text/uri-list", "text/plain"]
                    onEntered: if (!tab.active) switchTimer.restart()
                    onExited: switchTimer.stop()
                    onDropped: (drop) => {
                        switchTimer.stop()
                        const p = DropUtil.paths(drop).filter(x => x !== tab.modelData.loc)
                        if (!p.length) return
                        drop.acceptProposedAction()
                        root.dropped(tab.index, p, DropUtil.isCopy(drop))
                    }
                }
                Timer { id: switchTimer; interval: 600; onTriggered: root.activated(tab.index) }
            }
        }

        // neuer Tab
        Item {
            width: 36
            height: 34
            Button {
                id: plusBtn
                anchors.centerIn: parent
                variant: "ghost"
                size: "icon-sm"
                iconStart: String.fromCodePoint(0xF0415)
                onClicked: root.newRequested()
            }
            Tooltip { text: tr.t("files.newTabCtrlT"); shown: plusBtn.hovered }
        }
    }
}
