// Anzeigenamen für Sprachen (Locales) und Tastaturlayouts
.pragma library

var localeNames = {
    "de_DE": "Deutsch (Deutschland)", "de_AT": "Deutsch (Österreich)", "de_CH": "Deutsch (Schweiz)",
    "en_US": "English (USA)", "en_GB": "English (UK)", "fr_FR": "Français (France)",
    "es_ES": "Español (España)", "it_IT": "Italiano (Italia)", "nl_NL": "Nederlands",
    "pl_PL": "Polski", "pt_PT": "Português (Portugal)", "pt_BR": "Português (Brasil)",
    "tr_TR": "Türkçe", "ru_RU": "Русский", "uk_UA": "Українська", "sv_SE": "Svenska",
    "da_DK": "Dansk", "nb_NO": "Norsk", "fi_FI": "Suomi", "cs_CZ": "Čeština", "el_GR": "Ελληνικά",
    "ja_JP": "日本語", "zh_CN": "中文 (简体)", "ko_KR": "한국어"
}

function name(locale) {
    if (!locale) return "–"
    const base = locale.split(".")[0]
    return localeNames[base] ? localeNames[base] : locale
}

// [{ value: "de_DE.UTF-8", label: "Deutsch (Deutschland) – de_DE.UTF-8" }]
function localeOptions(list) {
    return list.filter(l => /utf-?8/i.test(l)).map(l => ({
        value: l, label: localeNames[l.split(".")[0]] ? localeNames[l.split(".")[0]] + "  ·  " + l : l
    })).sort((a, b) => a.label.localeCompare(b.label, "de"))
}

var keyboards = [
    { value: "de",      label: "keyboard.layoutGerman" },
    { value: "de:nodeadkeys", label: "keyboard.layoutGermanNoDeadKeys" },
    { value: "ch",      label: "keyboard.layoutGermanSwitzerland" },
    { value: "at",      label: "keyboard.layoutGermanAustria" },
    { value: "us",      label: "keyboard.layoutEnglishUs" },
    { value: "us:intl", label: "keyboard.layoutEnglishUsInternational" },
    { value: "gb",      label: "keyboard.layoutEnglishUk" },
    { value: "fr",      label: "keyboard.layoutFrench" },
    { value: "es",      label: "keyboard.layoutSpanish" },
    { value: "it",      label: "keyboard.layoutItalian" },
    { value: "nl",      label: "keyboard.layoutDutch" },
    { value: "pl",      label: "keyboard.layoutPolish" },
    { value: "tr",      label: "keyboard.layoutTurkish" },
    { value: "se",      label: "keyboard.layoutSwedish" },
    { value: "dk",      label: "keyboard.layoutDanish" },
    { value: "no",      label: "keyboard.layoutNorwegian" },
    { value: "pt",      label: "keyboard.layoutPortuguese" },
    { value: "ru",      label: "keyboard.layoutRussian" }
]

// Tastaturlayouts mit übersetzten Namen (label im Katalog der App)
function keyboardsT(tr) { return keyboards.map(k => Object.assign({}, k, { label: tr.t(k.label) })) }
