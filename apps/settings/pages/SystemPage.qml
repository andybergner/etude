import QtQuick
import Etude.Ui
import "../components"
import "../Nav.js" as Nav

// System-Startseite: Gerät oben, darunter alle Unterseiten als Zeilen
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property var device: ({})            // { hostname, model, network, battery }
    property var config: null            // Etude.Services/EtudeConfig (für die Vorschau)
    signal navigate(string path)

    spacing: 4

    // ===== Gerät + Status =====
    // breit:   Vorschau | Gerät …………………… Status (rechtsbündig, untereinander)
    // mittel:  Vorschau | Gerät, darunter Status
    // schmal:  alles untereinander
    Item {
        id: hero
        readonly property bool narrow: root.width < 560
        readonly property bool wide: root.width >= 760
        width: root.width
        height: narrow ? preview.height + 16 + infoCol.height
                       : Math.max(preview.height, infoCol.height, wide ? statusCol.height : 0)
        // ist der Text höher als die Vorschau, rutscht die Vorschau mit in die Mitte

        DesktopPreview {
            id: preview
            y: hero.narrow ? 0 : Math.max(0, (hero.height - height) / 2)
            width: Math.min(200, root.width)       // auf der Startseite kleiner
            wallpaper: root.config ? root.config.activeWallpaper : ""
            tint: root.config ? root.config.wallpaperColor : Theme.muted
            barTop: root.config ? root.config.barPosition === "top" : false
        }

        // Gerät (+ Status, wenn nicht breit)
        Column {
            id: infoCol
            x: hero.narrow ? 0 : preview.width + 24
            // mittig zur Vorschau
            y: hero.narrow ? preview.height + 16 : preview.y + (preview.height - height) / 2
            width: hero.narrow ? root.width
                 : hero.wide ? Math.min(280, root.width - preview.width - 24 - statusCol.width - 24)
                 : root.width - preview.width - 24
            spacing: 14

            Column {
                width: parent.width
                spacing: 2
                Text {
                    width: parent.width
                    text: root.device.hostname || tr.t("system.unnamed")
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.device.model || ""
                    elide: Text.ElideRight
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
                Text {
                    text: tr.t("system.rename")
                    color: Theme.primary
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    font.underline: renameMouse.containsMouse
                    MouseArea {
                        id: renameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigate("system/about")
                    }
                }
            }

            Loader { active: !hero.wide; visible: active; sourceComponent: statusComp }
        }

        // Status rechts (nur breit)
        Loader {
            id: statusCol
            active: hero.wide
            anchors.right: parent.right
            y: preview.y + (preview.height - height) / 2      // mittig zur Vorschau
            sourceComponent: statusComp
        }

        Component {
            id: statusComp
            Column {
                spacing: 10
                Repeater {
                    model: [
                        { icon: root.device.networkIcon || String.fromCodePoint(0xF05A9), label: tr.t("taskbar.moduleNetwork"),
                          desc: root.device.network || tr.t("network.notConnected"), show: true },
                        { icon: String.fromCodePoint(0xF008E), label: tr.t("taskbar.moduleBattery"), desc: root.device.battery || "", show: !!root.device.battery },
                        { icon: String.fromCodePoint(0xF06B0), label: tr.t("nav.update"), desc: tr.t("system.notChecked"), show: true }
                    ].filter(t => t.show)
                    delegate: StatusTile {
                        required property var modelData
                        icon: modelData.icon
                        label: modelData.label
                        desc: modelData.desc
                    }
                }
            }
        }
    }

    Item { width: 1; height: 12 }

    // ===== Unterseiten =====
    Repeater {
        model: Nav.pagesT(tr, "system")
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate("system/" + modelData.id)
        }
    }
}
