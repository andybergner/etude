// Suche über die App-Liste – reines JS, damit es auch ohne Quickshell testbar ist
.pragma library

function norm(s) {
    return (s || "").toLowerCase()
        .replace(/ä/g, "a").replace(/ö/g, "o").replace(/ü/g, "u").replace(/ß/g, "ss")
}

// Punkte: Name beginnt mit … > ein Wort im Namen beginnt mit … > Name enthält …
//         > Beschreibung/Stichwörter/Programmname enthalten …
function score(app, q) {
    const name = norm(app.name)
    if (name === q) return 120
    if (name.startsWith(q)) return 100
    if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80
    if (name.indexOf(q) >= 0) return 60
    const extra = norm([app.generic, app.keywords, app.id].join(" "))
    if (extra.split(/[\s\-_.;]+/).some(w => w.startsWith(q))) return 40
    if (extra.indexOf(q) >= 0) return 20
    return 0
}

function search(apps, query, limit) {
    const q = norm(query.trim())
    if (!q) return []
    return apps.map(a => ({ app: a, s: score(a, q) }))
        .filter(r => r.s > 0)
        .sort((a, b) => (b.s - a.s) || a.app.name.localeCompare(b.app.name, "de"))
        .slice(0, limit || 40)
        .map(r => r.app)
}
