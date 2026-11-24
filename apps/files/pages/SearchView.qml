import QtQuick
import Quickshell
import Quickshell.Io
import Etude.Ui
import "../components"
import "../FileIcons.js" as Icons

// Suche im aktuellen Ordner und allen Unterordnern (wie die Suche im Windows-Explorer).
// Ergebnisse als Liste mit Ordner; Auswahl, Öffnen, Kontextmenü und Tastenkürzel wie in FolderView.
FocusScope {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    required property var ops              // FileOps.qml (Skriptpfad, Aktualisieren nach Änderungen)
    property string path: ""               // hier wird gesucht
    property string query: ""
    property bool showHidden: false
    property var cutPaths: []

    property var results: []               // [{ path, name, dir, isDir, size, time }]
    property bool searching: false
    property bool truncated: false
    readonly property int limit: 2000

    property var selected: ({})
    property int anchorIndex: -1
    readonly property var selectedPaths: Object.keys(selected).filter(p => selected[p])
    readonly property int count: results.length
    readonly property var selectedDirs: results.reduce((o, r) => { if (selected[r.path] && r.isDir) o[r.path] = true; return o }, {})
    readonly property real selectedSize: results.reduce((s, r) => s + (selected[r.path] && !r.isDir ? r.size : 0), 0)

    signal openPath(string path, bool isDir)
    signal itemMenuRequested(real x, real y)
    signal action(string name)

    // ---- Suche (verzögert, damit nicht bei jedem Tastendruck gesucht wird) ----
    onQueryChanged: debounce.restart()
    onPathChanged: debounce.restart()
    onShowHiddenChanged: debounce.restart()
    Component.onCompleted: debounce.restart()
    Timer { id: debounce; interval: 250; onTriggered: root.start() }
    property bool restart: false
    function start() {
        const q = query.trim()
        if (!q || !path) { results = []; searching = false; return }
        if (proc.running) { restart = true; proc.signal(15); return }
        restart = false
        searching = true
        proc.command = ["sh", ops.script, "search", path, q, showHidden ? "1" : "0"]
        proc.running = true
    }
    Process {
        id: proc
        stdout: StdioCollector { id: out }
        onExited: {
            if (root.restart) { root.start(); return }
            const base = root.path === "/" ? "" : root.path
            const list = out.text.split("\n").filter(l => l).map(l => {
                const f = l.split("\x1f")
                const p = f.slice(3).join("\x1f")
                const dir = p.slice(0, p.lastIndexOf("/")) || "/"
                return { path: p, name: p.split("/").pop(), dir: dir, rel: dir === root.path ? "" : dir.slice(base.length + 1),
                         isDir: f[0] === "d", size: +f[1] || 0, time: (+f[2] || 0) * 1000 }
            })
            // Ordner zuerst, dann nach Name
            list.sort((a, b) => (b.isDir - a.isDir) || a.name.localeCompare(b.name, Qt.locale().name, { sensitivity: "base" }))
            root.truncated = list.length >= root.limit
            root.results = list
            root.searching = false
            const keep = {}
            for (const r of list) if (root.selected[r.path]) keep[r.path] = true
            root.selected = keep
        }
    }
    // nach Dateiaktionen (Umbenennen, Löschen …) neu suchen
    Connections { target: root.ops; function onChanged() { debounce.restart() } }

    // ---- Auswahl ----
    function selectedItems() { return results.filter(r => selected[r.path]).map(r => ({ path: r.path, name: r.name, isDir: r.isDir })) }
    function clickItem(index, path, mods) {
        if (mods & Qt.ControlModifier) { const s = Object.assign({}, selected); s[path] = !s[path]; selected = s; anchorIndex = index }
        else if ((mods & Qt.ShiftModifier) && anchorIndex >= 0) {
            const s = {}
            for (let i = Math.min(anchorIndex, index); i <= Math.max(anchorIndex, index); i++) s[results[i].path] = true
            selected = s
        } else { const s = {}; s[path] = true; selected = s; anchorIndex = index }
        list.currentIndex = index
    }
    function selectWhenReady(path, rename) {}
    function selectAll() { const s = {}; for (const r of results) s[r.path] = true; selected = s }

    Keys.onPressed: (e) => {
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            const r = results[list.currentIndex]
            if (e.modifiers & Qt.AltModifier) root.action("properties")
            else if (r) root.openPath(r.path, r.isDir)
        }
        else if (ctrl && e.key === Qt.Key_A) selectAll()
        else if (ctrl && e.key === Qt.Key_C) root.action("copy")
        else if (ctrl && e.key === Qt.Key_X) root.action("cut")
        else if (ctrl && e.key === Qt.Key_Z) root.action("undo")
        else if (e.key === Qt.Key_Delete) root.action(shift ? "delete" : "trash")
        else if (e.key === Qt.Key_Escape && selectedPaths.length) selected = ({})
        else if ((e.key === Qt.Key_Down || e.key === Qt.Key_Up) && results.length) {
            const i = Math.max(0, Math.min(results.length - 1, list.currentIndex + (e.key === Qt.Key_Down ? 1 : -1)))
            clickItem(i, results[i].path, shift ? Qt.ShiftModifier : 0)
            list.positionViewAtIndex(i, ListView.Contain)
        }
        else return
        e.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: { root.selected = ({}); root.forceActiveFocus() }
    }

    // Zustand: sucht / keine Treffer
    Column {
        visible: root.results.length === 0
        anchors.centerIn: parent
        spacing: 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String.fromCodePoint(0xF0349)
            color: Theme.mutedForeground
            font.family: Theme.fontIcon; font.pixelSize: 40
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.searching ? tr.t("files.searching") : tr.t("files.noMatchesFor").arg(root.query.trim())
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 14
        }
    }

    // Kopf: Anzahl der Treffer
    Item {
        id: info
        visible: root.results.length > 0
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: visible ? 34 : 0
        Text {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: (root.truncated ? tr.t("files.firstResults").arg(root.limit) : tr.tn("files.results", root.results.length).arg(root.results.length))
                  + " " + tr.t("files.inFolderAndSub").arg(root.path.split("/").pop() || "/") + (root.searching ? "  ·  " + tr.t("files.updating") : "")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 12
        }
    }
    TableHeader {
        id: head
        visible: root.results.length > 0
        anchors { left: parent.left; right: parent.right; top: info.bottom; leftMargin: 12; rightMargin: 24 }
        columns: [
            { key: "name", label: tr.t("files.name"), width: 0, align: "left" },
            { key: "dir", label: tr.t("files.folder"), width: 220, align: "left" },
            { key: "date", label: tr.t("files.dateModified"), width: 150, align: "left" },
            { key: "size", label: tr.t("files.size"), width: 90, align: "right" }
        ]
        sortKey: ""
    }

    ListView {
        id: list
        visible: root.results.length > 0
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1

        delegate: Item {
            id: row
            required property int index
            required property var modelData
            readonly property var r: modelData
            readonly property bool sel: !!root.selected[r.path]
            width: list.width - 12
            height: 38
            opacity: root.cutPaths.indexOf(r.path) >= 0 ? 0.45 : 1

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: row.sel ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                HoverLayer { shown: mouse.containsMouse && !row.sel; level: 0.6 }
            }
            Row {
                anchors.fill: parent
                Item {
                    width: row.width - 460
                    height: row.height
                    FileIcon {
                        id: icon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        size: 20
                        name: row.r.name
                        path: row.r.path
                        isDir: row.r.isDir
                    }
                    Text {
                        anchors.left: icon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: row.r.name
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 13
                    }
                }
                Repeater {
                    model: [
                        { w: 220, t: row.r.rel ? row.r.rel : tr.t("files.thisFolder"), r: false },
                        { w: 150, t: Qt.formatDateTime(new Date(row.r.time), tr.t("files.dateTimeShort")), r: false },
                        { w: 90, t: row.r.isDir ? "" : Icons.bytes(row.r.size, I18n.locale.decimalPoint), r: true }
                    ]
                    Text {
                        required property var modelData
                        width: modelData.w
                        height: row.height
                        leftPadding: 12
                        rightPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: modelData.r ? Text.AlignRight : Text.AlignLeft
                        elide: modelData.r ? Text.ElideRight : Text.ElideLeft
                        text: modelData.t
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans; font.pixelSize: 13
                        font.features: { "tnum": 1 }
                    }
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (e) => {
                    root.forceActiveFocus()
                    if (e.button === Qt.RightButton) {
                        if (!root.selected[row.r.path]) root.clickItem(row.index, row.r.path, 0)
                        const p = mapToItem(root, e.x, e.y)
                        root.itemMenuRequested(p.x, p.y)
                    } else root.clickItem(row.index, row.r.path, e.modifiers)
                }
                onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) root.openPath(row.r.path, row.r.isDir) }
            }
        }
    }
}
