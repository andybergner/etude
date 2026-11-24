.pragma library
// Mehrzahl-Kategorien nach CLDR für ganze Zahlen. Ein Katalogeintrag mit Mehrzahl ist ein Objekt
// { "one": "%1 Datei", "other": "%1 Dateien" }; "other" gibt es immer, dazu die Kategorien,
// die die Sprache braucht. Weitere Sprachen hier ergänzen.

function category(code, count) {
    const n = Math.abs(Math.trunc(Number(count) || 0))
    const n10 = n % 10, n100 = n % 100
    switch (String(code || "").split("-")[0]) {
    case "ja": case "ko": case "zh": case "th": case "vi": case "id":
        return "other"
    case "fr":
        return n <= 1 ? "one" : "other"
    case "cs": case "sk":
        return n === 1 ? "one" : (n >= 2 && n <= 4) ? "few" : "other"
    case "pl":
        if (n === 1) return "one"
        return (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) ? "few" : "many"
    case "ru": case "uk":
        if (n10 === 1 && n100 !== 11) return "one"
        return (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) ? "few" : "many"
    default:                               // en, de, nl, es, it, sv, da, …
        return n === 1 ? "one" : "other"
    }
}

// Form eines Eintrags für count; ein einfacher Text gilt für jede Zahl
function pick(entry, code, count) {
    if (typeof entry === "string") return entry
    if (!entry || typeof entry !== "object") return undefined
    const form = entry[category(code, count)]
    return typeof form === "string" && form.length ? form : entry.other
}
