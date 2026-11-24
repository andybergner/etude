import QtQuick
import Etude.Ui

// Verlaufsgrafik wie im Windows-Task-Manager: Raster, Fläche und Linie (rechts = jetzt).
//   Graph { values: sys.history.cpu; maxValue: 1 }
//   Graph { values: rx; values2: tx; maxValue: 0 }      // 0 = Skala automatisch
Rectangle {
    id: root

    property var values: []
    property var values2: []              // zweite Linie (gestrichelt), z. B. Senden
    property real maxValue: 1             // 0 = automatisch
    property int points: 60
    property color lineColor: Theme.primary
    property color lineColor2: Theme.alpha(Theme.primary, 0.6)
    property bool grid: true
    property bool mini: false             // kleine Vorschau (Seitenleiste)

    readonly property real scaleMax: {
        if (maxValue > 0) return maxValue
        const all = (values || []).concat(values2 || [])
        const m = Math.max(1, ...all)
        // auf eine runde Zahl aufrunden (1, 2, 5 × 10^n)
        const e = Math.pow(10, Math.floor(Math.log10(m)))
        const n = m / e
        return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * e
    }

    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(root.lineColor, root.mini ? 0.5 : 0.35)
    radius: mini ? 3 : Theme.radiusSm

    onValuesChanged: canvas.requestPaint()
    onValues2Changed: canvas.requestPaint()
    onScaleMaxChanged: canvas.requestPaint()
    onLineColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 1
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function series(ctx, vals, color, fill, dashed) {
            if (!vals || vals.length === 0) return
            const w = width, h = height
            const step = w / (root.points - 1)
            const off = root.points - vals.length
            const y = (v) => h - Math.min(1, Math.max(0, v / root.scaleMax)) * (h - 1)
            ctx.beginPath()
            for (let i = 0; i < vals.length; i++) {
                const x = (off + i) * step
                if (i === 0) ctx.moveTo(x, y(vals[i])); else ctx.lineTo(x, y(vals[i]))
            }
            if (fill) {
                ctx.save()
                ctx.lineTo((off + vals.length - 1) * step, h)
                ctx.lineTo(off * step, h)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.14)
                ctx.fill()
                ctx.restore()
                ctx.beginPath()
                for (let i = 0; i < vals.length; i++) {
                    const x = (off + i) * step
                    if (i === 0) ctx.moveTo(x, y(vals[i])); else ctx.lineTo(x, y(vals[i]))
                }
            }
            ctx.setLineDash(dashed ? [4, 3] : [])
            ctx.strokeStyle = color
            ctx.lineWidth = root.mini ? 1 : 1.5
            ctx.stroke()
            ctx.setLineDash([])
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            if (root.grid && !root.mini) {
                ctx.strokeStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.12)
                ctx.lineWidth = 1
                ctx.beginPath()
                for (let i = 1; i < 10; i++) { const x = Math.round(w * i / 10) + 0.5; ctx.moveTo(x, 0); ctx.lineTo(x, h) }
                for (let i = 1; i < 10; i++) { const yy = Math.round(h * i / 10) + 0.5; ctx.moveTo(0, yy); ctx.lineTo(w, yy) }
                ctx.stroke()
            }
            series(ctx, root.values, root.lineColor, true, false)
            series(ctx, root.values2, root.lineColor2, false, true)
        }
    }
}
