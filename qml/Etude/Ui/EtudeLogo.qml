import QtQuick

// Etude-Logo: eckiges O, diagonal geteilt (oben links hell, unten rechts Akzent).
// Gezeichnet statt als Bild, damit sich die Farben ans Theme anpassen.
//
//   EtudeLogo { size: 20 }                         // nur das Zeichen
//   EtudeLogo { size: 64; tile: true }             // App-Icon mit Kachel
//   EtudeLogo { size: 18; monoColor: "white" }     // einfarbiges Icon
Item {
    id: root

    property real size: 24
    property color colorTop: "#c0caf5"
    property color colorBottom: "#7aa2f7"
    property bool tile: false
    // Einfarbig, z. B. als Icon in der Leiste: beide Hälften in dieser Farbe
    property color monoColor: "transparent"
    readonly property bool mono: monoColor.a > 0
    property color tileColor: "#1a1b26"

    implicitWidth: size
    implicitHeight: size

    // Kachel wie beim App-Icon (Radius 42/512)
    Rectangle {
        anchors.fill: parent
        visible: root.tile
        radius: root.size * 42 / 512
        color: root.tileColor
    }

    Canvas {
        id: canvas
        // Mit Kachel nimmt das Zeichen 271/512 der Fläche ein, ohne Kachel die ganze Fläche
        readonly property real markSize: root.tile ? root.size * 271 / 512 : root.size
        width: markSize; height: markSize
        anchors.centerIn: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            const s = width
            const i0 = s * 0.2443, i1 = s * 0.7557   // innere Öffnung
            const gap = s * 0.0939                  // halbe Breite des diagonalen Schnitts (x+y)
            ctx.reset()

            function ring() {
                ctx.beginPath()
                ctx.rect(0, 0, s, s)
                ctx.rect(i0, i0, i1 - i0, i1 - i0)
            }

            // obere Hälfte: x + y <= s - gap
            ctx.save()
            ctx.beginPath()
            ctx.moveTo(0, 0); ctx.lineTo(s - gap, 0); ctx.lineTo(0, s - gap); ctx.closePath()
            ctx.clip()
            ring()
            ctx.fillStyle = root.mono ? root.monoColor : root.colorTop
            ctx.fillRule = Qt.OddEvenFill
            ctx.fill()
            ctx.restore()

            // untere Hälfte: x + y >= s + gap
            ctx.save()
            ctx.beginPath()
            ctx.moveTo(s, gap); ctx.lineTo(s, s); ctx.lineTo(gap, s); ctx.closePath()
            ctx.clip()
            ring()
            ctx.fillStyle = root.mono ? root.monoColor : root.colorBottom
            ctx.fillRule = Qt.OddEvenFill
            ctx.fill()
            ctx.restore()
        }
    }

    onColorTopChanged: canvas.requestPaint()
    onMonoColorChanged: canvas.requestPaint()
    onColorBottomChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
}
