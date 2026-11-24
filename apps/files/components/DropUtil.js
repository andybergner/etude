// Pfade aus einem Drop lesen (Explorer-Fenster, andere Apps): file://-URLs oder Text
.pragma library

function paths(drop) {
    var list = []
    if (drop.hasUrls) for (var i = 0; i < drop.urls.length; i++) list.push(String(drop.urls[i]))
    else if (drop.hasText) list = drop.text.split(/\r?\n/)
    return list.map(function (u) { return u.trim() })
        .filter(function (u) { return u.indexOf("file://") === 0 || u.indexOf("/") === 0 })
        .map(function (u) { return u.indexOf("/") === 0 ? u : decodeURIComponent(u.replace(/^file:\/\//, "")) })
}
// Strg = kopieren, sonst verschieben
function isCopy(drop) { return drop.proposedAction === Qt.CopyAction }
