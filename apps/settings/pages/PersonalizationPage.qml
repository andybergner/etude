import QtQuick
import Etude.Ui
import "../components"
import "../Nav.js" as Nav

// Personalisierung (wie Windows 11): Vorschau oben, darunter die Unterpunkte
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config         // Etude.Services/EtudeConfig
    signal navigate(string path)

    spacing: 4

    Row {
        spacing: 24
        bottomPadding: 16
        DesktopPreview {
        width: Math.min(standardWidth, root.width)
            wallpaper: root.config.activeWallpaper
            tint: root.config.wallpaperColor
            barTop: root.config.barPosition === "top"
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: tr.t(root.config.dark ? "colors.dark" : "colors.light")
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Text {
                text: tr.t(root.config.accent ? "personalization.accentCustom" : "personalization.accentDefault")
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 12
            }
            Text {
                text: tr.t(root.config.barPosition === "top" ? "personalization.taskbarTop" : "personalization.taskbarBottom")
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 12
            }
        }
    }

    Repeater {
        model: Nav.pagesT(tr, "personalization")
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate("personalization/" + modelData.id)
        }
    }
}
