import QtQuick
import Quickshell
import Etude.Ui
import "../components"

// Personalisierung › Taskleiste
// Position, Aufbau (per Ziehen in einer Bildschirm-Vorschau), angeheftete Apps.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config         // Etude.Services/EtudeConfig
    property var apps: null              // Etude.Services/AppManager (zum Anheften)
    property var battery: null           // Etude.Services/Battery (Akku vorhanden?)
    property var bluetooth: null         // Etude.Services/Bluetooth (Adapter vorhanden?)

    spacing: 4

    Component.onCompleted: if (apps) apps.refresh()

    // Desktop-Einträge (reaktiv: die Liste lädt beim Start asynchron)
    readonly property var entries: DesktopEntries.applications.values
    function entryFor(id) { id = String(id).replace(/\.desktop$/, ""); return entries.find(e => e.id === id || e.id === id + ".desktop") || null }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0379)
        label: tr.t("taskbar.taskbarPosition")
        desc: tr.t("taskbar.whereTheBarSitsOn")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "bottom", label: tr.t("taskbar.bottom") }, { value: "top", label: tr.t("taskbar.top") }]
            value: root.config.barPosition
            onSelected: (v) => root.config.set("barPosition", v)
        }
    }

    // ===== Aufbau =====
    SectionTitle { text: tr.t("taskbar.layout") }

    Rectangle {
        width: root.width
        height: editor.implicitHeight + 40
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        BarLayoutEditor {
            id: editor
            x: 20; y: 20
            width: parent.width - 40
            layout: root.config.barLayout
            available: ({ battery: !!root.battery && root.battery.present, bluetooth: !!root.bluetooth && root.bluetooth.present })
            wallpaper: root.config.activeWallpaper
            tint: root.config.wallpaperColor
            barTop: root.config.barPosition === "top"
            onChanged: (l) => root.config.set("barLayout", l)
        }
    }

    Item {
        width: root.width
        height: 40
        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            variant: "ghost"
            size: "sm"
            iconStart: String.fromCodePoint(0xF0450)
            text: tr.t("taskbar.restoreDefault")
            enabled: JSON.stringify(root.config.barLayout) !== JSON.stringify(root.config.defaultBarLayout)
            onClicked: root.config.set("barLayout", root.config.defaultBarLayout)
        }
    }

    // ===== Angeheftete Apps =====
    Item {
        width: root.width
        height: pinTitle.implicitHeight
        SectionTitle { id: pinTitle; text: tr.t("taskbar.pinnedApps") }
        Button {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            variant: "outline"
            size: "sm"
            iconStart: String.fromCodePoint(0xF0403)
            text: tr.t("taskbar.pinApp")
            enabled: !!root.apps
            onClicked: { pick.value = ""; pinDialog.open() }
        }
    }
    Text {
        visible: (root.config.barPinned || []).length === 0
        width: root.width
        text: tr.t("taskbar.noPinnedAppsRightClick")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans; font.pixelSize: 13
    }
    Repeater {
        model: root.config.barPinned || []
        SettingRow {
            id: row
            required property var modelData
            required property int index
            readonly property var entry: root.entryFor(modelData)
            width: root.width
            chevron: false
            icon: String.fromCodePoint(0xF003B)
            iconSource: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
            label: entry ? entry.name : modelData
            desc: modelData
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"; size: "icon-sm"
                iconStart: String.fromCodePoint(0xF0143)
                enabled: row.index > 0
                opacity: enabled ? 1 : 0.4
                onClicked: { const l = root.config.barPinned.slice(); l.splice(row.index - 1, 0, l.splice(row.index, 1)[0]); root.config.set("barPinned", l) }
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"; size: "icon-sm"
                iconStart: String.fromCodePoint(0xF0140)
                enabled: row.index < root.config.barPinned.length - 1
                opacity: enabled ? 1 : 0.4
                onClicked: { const l = root.config.barPinned.slice(); l.splice(row.index + 1, 0, l.splice(row.index, 1)[0]); root.config.set("barPinned", l) }
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"; size: "sm"
                text: tr.t("taskbar.unpin")
                onClicked: root.config.set("barPinned", root.config.barPinned.filter(x => x !== row.modelData))
            }
        }
    }

    Dialog {
        id: pinDialog
        title: tr.t("taskbar.pinAnAppToThe")
        Field {
            width: parent.width
            label: tr.t("taskbar.app")
            Select {
                id: pick
                width: parent.width
                searchable: true
                placeholder: tr.t("taskbar.chooseAnApp")
                model: root.apps ? root.apps.apps
                    .filter(a => (root.config.barPinned || []).indexOf(a.id.replace(/\.desktop$/, "")) < 0)
                    .map(a => ({ value: a.id.replace(/\.desktop$/, ""), label: a.name })) : []
                onActivated: (v) => pick.value = v
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: tr.t("taskbar.pin")
                enabled: pick.value !== ""
                onClicked: { root.config.set("barPinned", (root.config.barPinned || []).concat([pick.value])); pinDialog.close() }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: pinDialog.close() }
        }
    }
}
