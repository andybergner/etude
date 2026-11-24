import QtQuick
import Quickshell
import Quickshell.Io
import Etude.Ui
import "../FileIcons.js" as Icons

// Detailbereich rechts (wie im Windows-Explorer, Alt+Umschalt+P):
// Vorschau (Bild, Textanfang oder großes Icon), Name, Typ und Eigenschaften der Auswahl.
// Ohne Auswahl: der aktuelle Ordner. Mehrere Elemente: Anzahl und Gesamtgröße.
Rectangle {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    required property string script        // scripts/fileops.sh
    property var ops: null                 // FileOps.qml: nach Änderungen neu laden
    property var paths: []                 // ausgewählte Pfade
    property string location: ""           // aktueller Ordner (ohne Auswahl)
    property real selectedSize: 0          // Größe der ausgewählten Dateien (von der Ansicht)
    property var dirs: ({})                // ausgewählte Ordner (von der Ansicht) – gilt sofort, ohne auf stat zu warten
    signal openRequested(string path)

    readonly property string path: paths.length === 1 ? paths[0] : paths.length === 0 ? location : ""
    readonly property string name: path === "/" ? tr.t("files.localDisk") : path.split("/").pop()
    property var info: null                // { type, size, created, modified, mime, count }
    property string text: ""               // Textvorschau
    property bool gone: false              // Element gibt es nicht mehr
    // Ordner: Typ von stat (immer englisch, LC_ALL=C) oder Anzahl der Einträge (gibt es nur bei Ordnern)
    readonly property bool isDir: info ? (info.type === "directory" || info.count >= 0) : (paths.length === 0 || !!dirs[path])
    readonly property bool isImage: !!path && !isDir && Icons.isImage(name)
    readonly property bool isText: !!info && !isDir && /^(text\/|application\/(json|xml|javascript|x-shellscript|x-yaml|toml|x-desktop))/.test(info.mime || "")

    color: Theme.alpha(Theme.background, 0.4)
    clip: true
    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.border }

    function fmt(ms) { return ms > 0 ? new Date(ms).toLocaleString(I18n.locale, tr.t("files.dateTimeFormat")) : "–" }
    function bytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0, v = b
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (v >= 100 || i === 0 ? Math.round(v) : I18n.formatNumber(v, 1)) + " " + u[i]
    }

    // ---- Daten laden (bei jedem Wechsel der Auswahl) ----
    onPathChanged: { info = null; text = ""; gone = false; loadTimer.restart() }
    Connections { target: root.ops; function onChanged() { loadTimer.restart() } }
    Component.onCompleted: loadTimer.restart()
    Timer {
        id: loadTimer
        interval: 120                      // beim schnellen Durchklicken nicht für jedes Element laden
        onTriggered: {
            if (!root.path || root.path === "trash") return
            infoProc.forPath = root.path
            infoProc.command = ["sh", root.script, "info", root.path]
            infoProc.running = true
        }
    }
    Process {
        id: infoProc
        property string forPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (infoProc.forPath !== root.path) return
                const f = this.text.trim().split("\x1f")
                if (f.length < 4) { root.info = null; root.text = ""; root.gone = true; return }
                root.gone = false
                const inf = { type: f[0], size: +f[1] || 0, created: (+f[2] || 0) * 1000, modified: (+f[3] || 0) * 1000,
                              mime: f[4] || "", count: f[5] === "" || f[5] === undefined ? -1 : +f[5], dims: "" }
                // Abmessungen aus der Beschreibung von file(1), z. B. "PNG image data, 1920 x 1080, …" (letzter Treffer zählt)
                const re = /(\d+)\s*x\s*(\d+)/g
                let m
                while ((m = re.exec(f[6] || "")) !== null) inf.dims = m[1] + " × " + m[2]
                root.info = inf
                if (root.isText) {
                    textProc.forPath = root.path
                    textProc.command = ["sh", root.script, "preview", root.path]
                    textProc.running = true
                }
            }
        }
    }
    Process {
        id: textProc
        property string forPath: ""
        stdout: StdioCollector { onStreamFinished: if (textProc.forPath === root.path) root.text = this.text }
    }

    readonly property var rows: {
        if (!info) return []
        const r = []
        if (isDir) { if (info.count >= 0) r.push([tr.t("files.contents"), I18n.tn("common.items", info.count).arg(info.count)]) }
        else r.push([tr.t("files.size"), bytes(info.size)])
        if (info.dims) r.push([tr.t("files.dimensions"), tr.t("files.pixels").arg(info.dims)])
        r.push([tr.t("files.modified"), fmt(info.modified)])
        if (info.created > 0) r.push([tr.t("files.created"), fmt(info.created)])
        if (paths.length === 1) r.push([tr.t("files.location"), path.slice(0, path.lastIndexOf("/")) || "/"])
        return r
    }

    Text {
        visible: root.gone
        anchors.centerIn: parent
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: tr.t("files.theItemNoLongerExists")
        color: Theme.mutedForeground
        font.family: Theme.fontSans; font.pixelSize: 13
    }
    Flickable {
        visible: !root.gone
        anchors.fill: parent
        anchors.leftMargin: 1
        contentHeight: col.implicitHeight + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            x: 20; y: 20
            width: parent.width - 40
            spacing: 16

            // ===== Vorschau =====
            Rectangle {
                width: parent.width
                height: root.paths.length > 1 ? 150 : Math.min(220, width * 0.75)
                radius: Theme.radiusLg
                color: Theme.alpha(Theme.muted, 0.5)
                border.width: 1
                border.color: Theme.border
                clip: true

                // Bild
                Image {
                    id: preview
                    visible: root.isImage && status === Image.Ready
                    anchors.fill: parent
                    anchors.margins: 8
                    source: root.isImage ? "file://" + root.path : ""
                    sourceSize: Qt.size(600, 600)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                // Textanfang
                Text {
                    visible: root.isText && root.text !== ""
                    anchors.fill: parent
                    anchors.margins: 12
                    text: root.text
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    clip: true
                    color: Theme.foreground
                    font.family: Theme.fontMono; font.pixelSize: 11
                    lineHeight: 1.15
                }
                // mehrere Elemente: gestapelte Icons
                Item {
                    visible: root.paths.length > 1
                    anchors.centerIn: parent
                    width: 96; height: 96
                    Repeater {
                        model: Math.min(3, root.paths.length)
                        FileIcon {
                            required property int index
                            x: (2 - index) * 10; y: index * 6
                            size: 72
                            readonly property string p: root.paths[root.paths.length - 1 - index] || ""
                            name: p.split("/").pop()
                            path: p
                            isDir: !/\.[^./]+$/.test(name)
                            rotation: (index - 1) * 6
                        }
                    }
                }
                // sonst: großes Icon
                FileIcon {
                    visible: root.paths.length <= 1 && !preview.visible && !(root.isText && root.text !== "")
                    anchors.centerIn: parent
                    size: 96
                    name: root.name
                    path: root.path
                    isDir: root.isDir || root.paths.length === 0
                    thumbnail: true
                }
            }

            // ===== Name =====
            Column {
                width: parent.width
                spacing: 4
                Text {
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: root.paths.length > 1 ? tr.tn("files.selectedCount", root.paths.length).arg(root.paths.length) : root.name
                    color: Theme.foreground
                    font.family: Theme.fontSans; font.pixelSize: 15; font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.paths.length > 1
                          ? (root.selectedSize > 0 ? tr.t("files.filesTotal").arg(root.bytes(root.selectedSize)) : "")
                          : Icons.typeLabel(root.name, root.isDir, tr)
                    visible: text !== ""
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 12
                }
            }

            Button {
                visible: root.paths.length === 1
                variant: "outline"
                size: "sm"
                iconStart: String.fromCodePoint(0xF0770)
                text: I18n.t("common.open")
                onClicked: root.openRequested(root.path)
            }

            Rectangle { visible: root.rows.length > 0 && root.paths.length <= 1; width: parent.width; height: 1; color: Theme.border }

            // ===== Eigenschaften =====
            Column {
                visible: root.paths.length <= 1
                width: parent.width
                spacing: 10
                Repeater {
                    model: root.paths.length <= 1 ? root.rows : []
                    Column {
                        required property var modelData
                        width: col.width
                        spacing: 2
                        Text { text: modelData[0]; color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                        Text {
                            width: parent.width
                            wrapMode: Text.WrapAnywhere
                            text: modelData[1]
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
