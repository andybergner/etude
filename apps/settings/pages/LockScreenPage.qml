import QtQuick
import Etude.Ui
import "../components"
import "../components/Palette.js" as Palette

// Personalisierung › Sperrbildschirm: Hintergrund für Sperr- und Anmeldebildschirm
// (wie Desktop, eigener Farbton oder eigenes Bild). Der Anmeldebildschirm übernimmt ihn automatisch.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config         // Etude.Services/EtudeConfig
    spacing: 4

    readonly property string mode: config.lockWallpaperMode || "desktop"

    function pick(path) { config.set("lockWallpaper", path); config.set("lockWallpaperMode", "image") }

    // ===== Vorschau =====
    LockPreview {
        width: Math.min(standardWidth, root.width)
        wallpaper: root.config.lockActiveWallpaper
        tint: root.config.lockTint
        clock24: root.config.clock24
    }
    Item { width: 1; height: 12 }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF033E)
        label: tr.t("lockscreen.personalize")
        desc: tr.t("lockscreen.personalizeDesc")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "desktop", label: tr.t("lockscreen.likeDesktop") },
                      { value: "color", label: tr.t("background.solidColor") },
                      { value: "image", label: tr.t("background.picture") }]
            value: root.mode
            onSelected: (v) => {
                // beim ersten Wechsel auf „Bild“: aktuelles Desktop-Bild bzw. erstes gefundenes Bild nehmen
                if (v === "image" && !root.config.lockWallpaper) {
                    const first = root.config.wallpaper || (picker.images.length > 0 ? picker.images[0] : "")
                    if (first) root.config.set("lockWallpaper", first)
                }
                root.config.set("lockWallpaperMode", v)
            }
        }
    }

    // ===== Farbton =====
    SectionTitle { visible: root.mode === "color"; text: tr.t("background.chooseAColor") }
    ColorPicker {
        visible: root.mode === "color"
        width: root.width
        colors: Palette.colorsT(tr)
        fallback: Palette.defaultBackground
        value: root.config.lockWallpaperColor.toLowerCase() === Palette.defaultBackground ? "" : root.config.lockWallpaperColor
        onSelected: (v) => root.config.set("lockWallpaperColor", v || Palette.defaultBackground)
    }

    // ===== Bild =====
    WallpaperPicker {
        id: picker
        visible: root.mode === "image"
        width: root.width
        current: root.config.lockWallpaper
        onPicked: (path) => root.pick(path)
    }

    // ===== Hinweis Anmeldebildschirm =====
    Text {
        width: root.width
        topPadding: 16
        text: tr.t("lockscreen.signInHint")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
