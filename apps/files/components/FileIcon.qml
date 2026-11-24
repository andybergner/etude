import QtQuick
import Quickshell
import Etude.Ui
import "../FileIcons.js" as Icons

// Datei-Icon: Vorschaubild bei Bildern (Raster), Ordner mit dem Etude-Ordnersymbol,
// sonst Icon aus dem Icon-Theme, sonst Glyph.
Item {
    id: root

    property string name: ""
    property string path: ""
    property bool isDir: false
    property string iconOverride: ""       // z. B. "folder-download" für persönliche Ordner
    property real size: 32
    property bool thumbnail: false

    width: size
    height: size

    readonly property bool showThumb: thumbnail && !isDir && Icons.isImage(name)
    // Ordner: Etude-Ordnersymbol (Form aus icons/folder.svg), eingefärbt in der Akzentfarbe des Systems;
    // ohne Akzentfarbe das gelbe Original
    readonly property string folderIcon: Theme.hasBrand ? tinted(Theme.brand) : Qt.resolvedUrl("../icons/folder.svg")
    function hex(c) { const h = (v) => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2); return "#" + h(c.r) + h(c.g) + h(c.b) }
    function mix(c, w, f) { return Qt.rgba(c.r + (w - c.r) * f, c.g + (w - c.g) * f, c.b + (w - c.b) * f, 1) }
    function tinted(c) {
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><defs>' +
            '<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + hex(mix(c, 0, 0.05)) + '"/><stop offset="1" stop-color="' + hex(mix(c, 0, 0.32)) + '"/></linearGradient>' +
            '<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + hex(mix(c, 1, 0.5)) + '"/><stop offset="1" stop-color="' + hex(mix(c, 1, 0.12)) + '"/></linearGradient></defs>' +
            '<path d="M36 36h62q8 0 13 6l12 14h97q16 0 16 16v146q0 16-16 16H36q-16 0-16-16V52q0-16 16-16z" fill="url(#b)"/>' +
            '<path d="M20 96q0-16 16-16h184q16 0 16 16v114q0 16-16 16H36q-16 0-16-16z" fill="url(#f)"/></svg>'
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg)
    }
    readonly property string themeIcon: {
        if (isDir && !iconOverride) return folderIcon
        const n = iconOverride || Icons.iconName(name, isDir)
        return Quickshell.iconPath(n, true) || Quickshell.iconPath(isDir ? "folder" : "text-x-generic", true)
    }

    // Vorschaubild
    Image {
        id: thumb
        visible: root.showThumb && status === Image.Ready
        anchors.centerIn: parent
        width: root.size
        height: root.size
        source: root.showThumb ? "file://" + root.path : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
    }
    // Icon-Theme
    Image {
        id: themed
        visible: !thumb.visible && status === Image.Ready
        anchors.fill: parent
        source: !thumb.visible ? root.themeIcon : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true
    }
    // Ersatz: Glyph
    Text {
        visible: !thumb.visible && !themed.visible
        anchors.centerIn: parent
        text: Icons.glyph(root.name, root.isDir)
        color: root.isDir ? Theme.primary : Theme.mutedForeground
        font.family: Theme.fontIcon
        font.pixelSize: root.size * 0.85
    }
}
