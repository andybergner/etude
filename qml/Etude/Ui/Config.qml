import QtQuick
import Quickshell
import Quickshell.Io

// Etude-Einstellungen eines Bereichs (Domain) – nach dem Vorbild von Registry und GSettings.
//
//   Config { id: cfg; domain: "files" }
//   cfg.values.details          // lesen (in Bindungen)
//   cfg.set("details", true)    // nur diesen Schlüssel schreiben
//   cfg.reset("details")        // zurück auf den Standard
//
// Drei Ebenen, die untere gewinnt:
//   Schema   $ETUDE_HOME/default/schemas/<domain>.json bzw. /usr/share/etude/schemas  (Typ, Standard, Beschreibung)
//   Admin    /etc/etude/settings/<domain>.json   { "values": { … }, "locked": ["key"] }
//   Nutzer   ~/.config/etude/settings/<domain>.json   – nur, was vom Standard abweicht
// Eigenständige Apps nehmen ihre Reverse-DNS-ID als Domain und geben ihr Schema mit:
//   Config { domain: "com.example.snip"; schema: Qt.resolvedUrl("schema.json") }
// Geschrieben wird atomar (temporäre Datei + Umbenennen); andere Prozesse sehen Änderungen sofort.
QtObject {
    id: root

    property string domain: ""
    property url schema: ""

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string etudeHome: Quickshell.env("ETUDE_HOME") || "/usr/share/etude"
    readonly property string userPath: domain ? configHome + "/etude/settings/" + domain + ".json" : ""
    readonly property string adminPath: domain ? "/etc/etude/settings/" + domain + ".json" : ""

    // ---- Ebenen ----
    readonly property var schemaKeys: _parse(_schemaA.text || _schemaB.text, "schema")
    readonly property var admin: _parse(_admin.text, "admin")
    readonly property var locked: admin.locked || []
    readonly property var user: _parse(_user.text, "user")
    // Standard = Schema, überschrieben von Admin-Vorgaben
    readonly property var defaults: {
        const o = {}
        for (const k in schemaKeys) o[k] = schemaKeys[k].default
        const a = admin.values || {}
        for (const k in a) o[k] = a[k]
        return o
    }
    // Wirksame Werte; unbekannte Schlüssel des Nutzers bleiben erhalten (neuere App-Versionen)
    readonly property var values: {
        const o = Object.assign({}, defaults)
        for (const k in user) if (locked.indexOf(k) < 0) o[k] = user[k]
        return o
    }

    function value(key, fallback) { return values[key] !== undefined ? values[key] : fallback }
    function isLocked(key) { return locked.indexOf(key) >= 0 }
    function isDefault(key) { return user[key] === undefined }

    function set(key, value) {
        if (!domain) return false
        if (isLocked(key)) { console.warn("Config:", domain + "." + key, "is locked by the administrator"); return false }
        const s = schemaKeys[key]
        if (s && !_valid(s, value)) { console.warn("Config:", domain + "." + key, "invalid value", JSON.stringify(value)); return false }
        const cur = _parse(_user.fresh(), "user")
        if (_same(value, defaults[key])) {
            if (!(key in cur)) return true
            delete cur[key]                       // gleich dem Standard: nicht speichern, Standard folgen
        } else {
            if (key in cur && _same(cur[key], value)) return true
            cur[key] = value
        }
        _write(cur)
        return true
    }
    function reset(key) {
        if (!domain) return
        const cur = _parse(_user.fresh(), "user")
        if (!(key in cur)) return
        delete cur[key]
        _write(cur)
    }
    function resetAll() { if (domain) _write({}) }
    function reload() { _user.reopen(); _admin.reopen() }

    // ---- intern ----
    function _write(o) {
        const t = JSON.stringify(o, null, 2) + "\n"
        _user.text = t                            // sofort für diesen Prozess
        _writer.setText(t)
    }
    function _same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }
    function _parse(t, what) {
        if (!t) return ({})
        try {
            const o = JSON.parse(t)
            return o && typeof o === "object" && !Array.isArray(o) ? o : ({})
        } catch (e) { console.warn("Config:", domain, what, e); return ({}) }
    }
    function _valid(s, v) {
        switch (s.type) {
        case "bool":   return typeof v === "boolean"
        case "int":    return Number.isInteger(v) && (s.min === undefined || v >= s.min) && (s.max === undefined || v <= s.max)
        case "real":   return typeof v === "number" && (s.min === undefined || v >= s.min) && (s.max === undefined || v <= s.max)
        case "string": return typeof v === "string"
        case "color":  return typeof v === "string" && (v === "" || /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v))
        case "enum":   return (s.choices || []).indexOf(v) >= 0
        case "list":   return Array.isArray(v)
        case "object": return v !== null && typeof v === "object" && !Array.isArray(v)
        default:       return true
        }
    }
    function _local(u) { return decodeURIComponent(String(u).replace(/^file:\/\//, "")) }

    property WatchedFile _user: WatchedFile { path: root.userPath }
    property WatchedFile _admin: WatchedFile { path: root.adminPath }
    property WatchedFile _schemaA: WatchedFile {
        path: String(root.schema) !== "" ? root._local(root.schema)
            : root.domain ? root.etudeHome + "/default/schemas/" + root.domain + ".json" : ""
    }
    property WatchedFile _schemaB: WatchedFile {
        path: String(root.schema) === "" && root.domain ? "/usr/share/etude/schemas/" + root.domain + ".json" : ""
    }
    property FileView _writer: FileView {
        path: root.userPath
        preload: false
        printErrors: true
    }
}
