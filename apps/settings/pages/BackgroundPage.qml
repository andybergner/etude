import QtQuick
import Etude.Ui
import "../components"
import "../components/Palette.js" as Palette

// Personalisierung › Hintergrund: Farbton oder Bild für den Desktop (Sperrbildschirm: eigene Seite)
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config         // Etude.Services/EtudeConfig
    spacing: 4

    function pick(path) { config.set("wallpaper", path); config.set("wallpaperMode", "image") }

    readonly property bool imageMode: config.wallpaperMode === "image"


    // ===== Vorschau =====
    DesktopPreview {
        width: Math.min(standardWidth, root.width)
        wallpaper: root.config.activeWallpaper
        tint: root.config.wallpaperColor
        barTop: root.config.barPosition === "top"
    }
    Item { width: 1; height: 12 }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0976)
        label: tr.t("background.personalizeYourBackground")
        desc: tr.t("background.appliesToTheDesktopAnd")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "color", label: tr.t("background.solidColor") }, { value: "image", label: tr.t("background.picture") }]
            value: root.config.wallpaperMode
            onSelected: (v) => {
                // beim ersten Wechsel auf tr.t("background.picture") direkt das erste Etude-Bild nehmen
                if (v === "image" && !root.config.wallpaper && picker.images.length > 0)
                    root.config.set("wallpaper", picker.images[0])
                root.config.set("wallpaperMode", v)
            }
        }
    }

    // ===== Farbton =====
    SectionTitle { visible: !root.imageMode; text: tr.t("background.chooseAColor") }

    ColorPicker {
        visible: !root.imageMode
        width: root.width
        colors: Palette.colorsT(tr)          // dieselben Farben wie die Akzentfarbe
        fallback: Palette.defaultBackground
        value: root.config.wallpaperColor.toLowerCase() === Palette.defaultBackground ? "" : root.config.wallpaperColor
        onSelected: (v) => root.config.set("wallpaperColor", v || Palette.defaultBackground)
    }

    // ===== Bild =====
    WallpaperPicker {
        id: picker
        visible: root.imageMode
        width: root.width
        current: root.config.wallpaper
        onPicked: (path) => root.pick(path)
    }
}
