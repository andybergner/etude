// Icons und Typnamen nach Dateiendung (freedesktop-Iconnamen, Adwaita & Co.)
.pragma library

var types = {
    image:   { exts: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "tif", "tiff", "heic", "avif", "ico"], icon: "image-x-generic", label: "type.image" },
    video:   { exts: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv", "flv"], icon: "video-x-generic", label: "type.video" },
    audio:   { exts: ["mp3", "flac", "ogg", "oga", "opus", "wav", "m4a", "aac", "wma"], icon: "audio-x-generic", label: "type.audio" },
    pdf:     { exts: ["pdf"], icon: "application-pdf", label: "type.pdfDocument" },
    doc:     { exts: ["doc", "docx", "odt", "rtf"], icon: "x-office-document", label: "type.textDocument" },
    sheet:   { exts: ["xls", "xlsx", "ods", "csv"], icon: "x-office-spreadsheet", label: "type.spreadsheet" },
    slides:  { exts: ["ppt", "pptx", "odp"], icon: "x-office-presentation", label: "type.presentation" },
    archive: { exts: ["zip", "tar", "gz", "tgz", "xz", "zst", "bz2", "7z", "rar"], icon: "package-x-generic", label: "type.archive" },
    script:  { exts: ["sh", "bash", "zsh", "fish", "py", "js", "ts", "lua", "rb", "pl"], icon: "text-x-script", label: "type.script" },
    code:    { exts: ["c", "h", "cpp", "hpp", "rs", "go", "java", "qml", "html", "css", "json", "xml", "yaml", "yml", "toml"], icon: "text-x-generic", label: "type.sourceCode" },
    text:    { exts: ["txt", "md", "log", "conf", "ini", "cfg"], icon: "text-x-generic", label: "type.textFile" },
    disk:    { exts: ["iso", "img", "qcow2"], icon: "media-optical", label: "type.diskImage" },
    package: { exts: ["pkg", "deb", "rpm", "appimage"], icon: "package-x-generic", label: "type.package" },
    desktop: { exts: ["desktop"], icon: "application-x-executable", label: "type.shortcut" }
}

var byExt = {}
for (var k in types) for (var i = 0; i < types[k].exts.length; i++) byExt[types[k].exts[i]] = k

function kind(name, isDir) {
    if (isDir) return "folder"
    var dot = name.lastIndexOf(".")
    if (dot <= 0) return "file"
    return byExt[name.slice(dot + 1).toLowerCase()] || "file"
}
function iconName(name, isDir) {
    var k = kind(name, isDir)
    if (k === "folder") return "folder"
    return types[k] ? types[k].icon : "text-x-generic"
}
// tr: Translations des Explorers (Typnamen stehen im Katalog: type.*)
function typeLabel(name, isDir, tr) {
    var k = kind(name, isDir)
    if (k === "folder") return tr.t("type.folder")
    if (types[k]) return tr.t(types[k].label)
    var dot = name.lastIndexOf(".")
    return dot > 0 ? tr.t("type.extFile").arg(name.slice(dot + 1).toUpperCase()) : tr.t("type.file")
}
function isImage(name) { return kind(name, false) === "image" && !/\.(svg|heic|avif)$/i.test(name) }

// Glyph (Nerd Font) als Ersatz, falls kein Icon-Theme da ist
var glyphs = { folder: 0xF024B, image: 0xF0976, video: 0xF0567, audio: 0xF075A, pdf: 0xF0226, doc: 0xF0219,
               sheet: 0xF021B, slides: 0xF0227, archive: 0xF05C4, script: 0xF018D, code: 0xF0169, text: 0xF0219,
               disk: 0xF02CA, package: 0xF03D7, desktop: 0xF0493, file: 0xF0214 }
function glyph(name, isDir) { return String.fromCodePoint(glyphs[kind(name, isDir)] || 0xF0214) }

function bytes(b, dec) {   // dec: Dezimaltrennzeichen (I18n.locale.decimalPoint)
    if (b === undefined || b === null || isNaN(b)) return ""
    var u = ["B", "KB", "MB", "GB", "TB"], i = 0, v = b
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
    return (v >= 100 || i === 0 ? String(Math.round(v)) : v.toFixed(1).replace(".", dec || ".")) + " " + u[i]
}
