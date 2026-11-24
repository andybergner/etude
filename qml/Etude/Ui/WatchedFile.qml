import QtQuick
import Quickshell.Io

// Kleine lokale Datei (Sprachdatei, Übersetzungskatalog): Text synchron lesen und bei jeder
// Änderung neu einlesen. Synchron, damit schon die erste Bindung den fertigen Text bekommt
// statt kurz den Schlüssel. Zwei FileViews: einer liest (blockierend), einer beobachtet.
QtObject {
    id: root

    property string path: ""

    // Pfad wird beim Lesen gesetzt (nicht gebunden), damit er beim ersten Lesen schon stimmt
    readonly property FileView reader: FileView {
        printErrors: false
        preload: false
        blockAllReads: true
    }
    readonly property FileView watcher: FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        preload: false
        onFileChanged: root.text = root.load(root.path, true)
    }

    property string text: load(path, false)

    function load(p, again) {
        if (!reader) return ""
        if (reader.path !== p) reader.path = p
        else if (again) { watcher.reload(); reader.reload() }
        return p ? (reader.text() || "") : ""
    }
    onPathChanged: text = load(path, false)

    // Jetzt neu von der Platte lesen (z. B. direkt vor dem Schreiben)
    function fresh() { text = load(path, true); return text }
    // Beobachtung neu aufsetzen (wenn der Ordner erst später angelegt wurde)
    function reopen() { const p = path; path = ""; path = p }
}
