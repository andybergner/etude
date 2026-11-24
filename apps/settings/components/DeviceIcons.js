// Icon je Bluetooth-Gerätetyp (BlueZ "Icon"-Eigenschaft bzw. Name)
.pragma library

function g(cp) { return String.fromCodePoint(cp) }

function icon(kind) {
    kind = (kind || "").toLowerCase()
    if (kind.indexOf("headset") >= 0) return g(0xF02CE)
    if (kind.indexOf("audio") >= 0 || kind.indexOf("head") >= 0 || kind.indexOf("speaker") >= 0) return g(0xF02CB)
    if (kind.indexOf("keyboard") >= 0) return g(0xF030C)
    if (kind.indexOf("mouse") >= 0) return g(0xF037D)
    if (kind.indexOf("phone") >= 0) return g(0xF011C)
    if (kind.indexOf("computer") >= 0) return g(0xF0322)
    if (kind.indexOf("game") >= 0) return g(0xF0297)
    return g(0xF00AF)
}
