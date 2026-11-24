// Symbole für Netzwerk und Akku auf Sperr- und Anmeldebildschirm (gleiche Glyphen wie die Taskleiste)
.pragma library

function g(cp) { return String.fromCodePoint(cp) }

// kind: "ethernet" | "wifi" | sonst; signal: 0–100
function network(kind, signal) {
    if (kind === "ethernet") return g(0xF0200)
    if (kind === "wifi") return g(signal > 75 ? 0xF0928 : signal > 50 ? 0xF0925 : signal > 25 ? 0xF0922 : 0xF091F)
    return g(0xF0A8E)
}

function battery(level, charging) {
    if (charging) return g(0xF0084)
    if (level >= 95) return g(0xF0079)
    if (level < 5) return g(0xF0083)
    return g(0xF007A + Math.min(8, Math.max(0, Math.floor(level / 10) - 1)))
}
