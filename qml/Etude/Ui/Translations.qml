import QtQuick
import Quickshell
import "Plural.js" as Plural

// Übersetzungen eines Bereichs. Die Texte von Etude liegen wie bei Omarchy gesammelt in
// default/i18n/<sprache>/<bereich>.json (Paket: /usr/share/etude/default/i18n):
//
//   Translations { id: tr; domain: "files" }       → default/i18n/de/files.json, …/en/files.json
//
// Eigenständige Apps mit Etude.Ui bringen ihre Texte selbst mit, als Ordner mit en.json, de.json …:
//
//   Translations { id: tr; domain: "ui" }
//
// Benutzung:
//   Text { text: tr.t("files.newFolder") }
//   Text { text: tr.t("files.selected").arg(n) }                       // %1, %2 … für Werte
//   Text { text: tr.tn("files.items", n).arg(I18n.formatNumber(n)) }  // Mehrzahl
//
// Ein Katalog ist flach: { "files.newFolder": "New folder", "files.items": { "one": "%1 item",
// "other": "%1 items" } }. Fehlt ein Text in der Systemsprache, gilt die Grundsprache
// (pt-BR → pt), dann Englisch, dann der Schlüssel selbst. Sprachwechsel wirken sofort.
QtObject {
    id: root

    property string domain: ""                  // Bereich in default/i18n, z. B. "settings"
    property var directory: ""                  // eigener Ordner (eigenständige Apps), Pfad oder file://-URL
    property string language: ""                // leer = Sprache von Etude (I18n.language)
    readonly property string lang: language || I18n.language

    readonly property string baseLanguage: lang.split("-")[0]
    readonly property string directoryPath: String(directory).replace(/^file:\/\//, "").replace(/\/+$/, "")
    // ETUDE_HOME: Paket /usr/share/etude, Entwicklung das Repo
    readonly property string i18nRoot: (Quickshell.env("ETUDE_HOME") || "/usr/share/etude") + "/default/i18n"

    readonly property var englishStrings: parse(englishFile.text)
    readonly property var baseStrings: parse(baseFile.text)
    readonly property var languageStrings: parse(languageFile.text)

    function t(key, fallback) {
        const layers = [languageStrings, baseStrings, englishStrings]
        for (const l of layers) {
            let v = l[key]
            if (v && typeof v === "object") v = v.other
            if (typeof v === "string" && v.length) return v
        }
        return fallback !== undefined ? fallback : key
    }
    function tn(key, count, fallback) {
        const layers = [[languageStrings, lang], [baseStrings, baseLanguage], [englishStrings, "en"]]
        for (const l of layers) {
            const v = Plural.pick(l[0][key], l[1], count)
            if (typeof v === "string" && v.length) return v
        }
        return fallback !== undefined ? fallback : key
    }
    function has(key) { return key in languageStrings || key in baseStrings || key in englishStrings }

    function parse(raw) {
        try {
            const p = JSON.parse(raw || "{}")
            return p && typeof p === "object" && !Array.isArray(p) ? p : ({})
        } catch (e) {
            console.warn("i18n: Katalog " + (domain || directoryPath) + " ist kein gültiges JSON: " + e)
            return ({})
        }
    }
    function file(code) {
        if (domain) return i18nRoot + "/" + code + "/" + domain + ".json"
        return directoryPath ? directoryPath + "/" + code + ".json" : ""
    }

    property WatchedFile englishFile: WatchedFile { path: root.file("en") }
    property WatchedFile baseFile: WatchedFile { path: root.baseLanguage !== root.lang && root.baseLanguage !== "en" ? root.file(root.baseLanguage) : "" }
    property WatchedFile languageFile: WatchedFile { path: root.lang !== "en" ? root.file(root.lang) : "" }
}
