// Waagerechte Position eines Menüs zum Button in der Leiste (Aufbau ist frei wählbar):
//   Button im linken Drittel  → Menü linksbündig zum Button
//   Button in der Mitte       → Menü mittig auf dem Bildschirm (wie das Windows-11-Startmenü)
//   Button im rechten Drittel → Menü am rechten Bildschirmrand
.pragma library

function x(anchorLeft, anchorRight, w, screenW) {
    if (anchorLeft < 0) return screenW - w - 8
    var c = (anchorLeft + anchorRight) / 2
    if (c < screenW / 3) return Math.max(8, Math.min(anchorLeft, screenW - w - 8))
    if (c > screenW * 2 / 3) return screenW - w - 8
    return Math.max(8, Math.round((screenW - w) / 2))
}
