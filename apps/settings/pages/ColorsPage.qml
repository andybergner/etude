import QtQuick
import Etude.Ui
import "../components"
import "../components/Palette.js" as Palette

// Personalisierung › Farben: Modus und Akzentfarbe
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config         // Etude.Services/EtudeConfig

    spacing: 4


    // dieselbe Vorschau wie auf den anderen Seiten – zeigt Modus, Akzent und Transparenz
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
        icon: String.fromCodePoint(0xF0594)
        label: tr.t("colors.mode")
        desc: tr.t("colors.lightOrDarkAppliesTo")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "light", label: tr.t("colors.light") }, { value: "dark", label: tr.t("colors.dark") }]
            value: root.config.dark ? "dark" : "light"
            onSelected: (v) => root.config.set("dark", v === "dark")
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0E0C)
        label: tr.t("colors.transparencyEffects")
        desc: tr.t("colors.theTaskbarMenusAndWindows")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.transparency
            onToggled: root.config.set("transparency", !root.config.transparency)
        }
    }

    SectionTitle { text: tr.t("colors.accentColor") }

    ColorPicker {
        width: root.width
        colors: Palette.colorsT(tr)
        value: root.config.accent
        onSelected: (v) => root.config.set("accent", v)
    }

    SectionTitle { text: tr.t("colors.preview") }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0E0C)
        label: tr.t("colors.thisIsWhatControlsLook")
        Button { anchors.verticalCenter: parent.verticalCenter; text: tr.t("colors.primary") }
        Button { anchors.verticalCenter: parent.verticalCenter; variant: "outline"; text: tr.t("colors.secondary") }
        Switch { anchors.verticalCenter: parent.verticalCenter; checked: true }
    }
}
