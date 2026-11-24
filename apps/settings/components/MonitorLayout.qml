import QtQuick
import Etude.Ui

// Anordnung der Bildschirme (wie Windows): Rechtecke mit Nummer, anklicken = auswählen,
// ziehen = verschieben. Beim Loslassen rastet der Bildschirm an der nächsten Kante eines
// anderen Bildschirms ein (keine Lücken, keine Überlappung).
Rectangle {
    id: root

    property var monitors: []            // aus Displays.qml
    property string selected: ""
    signal select(string name)
    signal moved(string name, int x, int y)

    implicitHeight: 220
    radius: Theme.radiusMd
    color: Theme.card
    border.width: 1
    border.color: Theme.border

    // logische Größe (Skalierung, Drehung um 90°/270° tauscht Breite und Höhe)
    function lw(m) { return ((m.transform % 2) ? m.height : m.width) / m.scale }
    function lh(m) { return ((m.transform % 2) ? m.width : m.height) / m.scale }

    readonly property var shown: monitors.filter(m => !m.disabled)
    readonly property real minX: Math.min.apply(null, shown.map(m => m.x).concat([0]))
    readonly property real minY: Math.min.apply(null, shown.map(m => m.y).concat([0]))
    readonly property real bw: Math.max.apply(null, shown.map(m => m.x + lw(m)).concat([1])) - minX
    readonly property real bh: Math.max.apply(null, shown.map(m => m.y + lh(m)).concat([1])) - minY
    readonly property real pad: 28
    readonly property real f: Math.min((width - 2 * pad) / bw, (height - 2 * pad) / bh)
    readonly property real ox: (width - bw * f) / 2
    readonly property real oy: (height - bh * f) / 2

    // nächstgelegene Andock-Position an einem anderen Bildschirm
    function snap(m, rx, ry) {
        const others = shown.filter(o => o.name !== m.name)
        if (others.length === 0) return { x: 0, y: 0 }
        let best = null, bestD = Infinity
        const w = lw(m), h = lh(m)
        for (const o of others) {
            const ow = lw(o), oh = lh(o)
            const clampY = Math.max(o.y - h + 1, Math.min(o.y + oh - 1, ry))
            const clampX = Math.max(o.x - w + 1, Math.min(o.x + ow - 1, rx))
            const cands = [
                { x: o.x + ow, y: clampY }, { x: o.x - w, y: clampY },      // rechts / links
                { x: clampX, y: o.y + oh }, { x: clampX, y: o.y - h }       // unten / oben
            ]
            for (const c of cands) {
                // an Ober-/Unterkante bzw. linker/rechter Kante ausrichten, wenn nah dran
                if (Math.abs(c.y - o.y) < 80) c.y = o.y
                if (Math.abs(c.x - o.x) < 80) c.x = o.x
                const d = Math.hypot(c.x - rx, c.y - ry)
                if (d < bestD) { bestD = d; best = c }
            }
        }
        return { x: Math.round(best.x), y: Math.round(best.y) }
    }

    Repeater {
        model: root.shown
        delegate: Rectangle {
            id: mon
            required property var modelData
            readonly property bool active: modelData.name === root.selected
            z: dragArea.drag.active ? 2 : (active ? 1 : 0)

            function place() {
                x = Qt.binding(() => root.ox + (mon.modelData.x - root.minX) * root.f)
                y = Qt.binding(() => root.oy + (mon.modelData.y - root.minY) * root.f)
            }
            Component.onCompleted: place()
            width: root.lw(modelData) * root.f
            height: root.lh(modelData) * root.f
            radius: Theme.radiusSm
            color: active ? Theme.alpha(Theme.primary, 0.25) : Theme.muted
            border.width: active ? 2 : 1
            border.color: active ? Theme.primary : Theme.border

            Text {
                anchors.centerIn: parent
                text: mon.modelData.id + 1
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Math.max(14, Math.min(40, parent.height * 0.4))
                font.weight: Font.DemiBold
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                visible: parent.height > 60
                text: mon.modelData.name
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 10
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: root.shown.length > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                drag.target: root.shown.length > 1 ? mon : null
                onPressed: root.select(mon.modelData.name)
                onReleased: {
                    // nur geklickt, nicht gezogen?
                    if (Math.abs(mon.x - (root.ox + (mon.modelData.x - root.minX) * root.f)) < 2
                        && Math.abs(mon.y - (root.oy + (mon.modelData.y - root.minY) * root.f)) < 2) return
                    const rx = root.minX + (mon.x - root.ox) / root.f
                    const ry = root.minY + (mon.y - root.oy) / root.f
                    const p = root.snap(mon.modelData, rx, ry)
                    mon.place()
                    if (p.x !== mon.modelData.x || p.y !== mon.modelData.y) root.moved(mon.modelData.name, p.x, p.y)
                }
            }
        }
    }
}
