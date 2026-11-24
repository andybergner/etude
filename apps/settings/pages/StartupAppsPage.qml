import QtQuick
import Etude.Ui
import "../components"

// Apps › Autostart (wie Windows 11): Apps, die beim Anmelden starten, einzeln ein- und ausschalten.
// Quelle: ~/.config/autostart und /etc/xdg/autostart (XDG-Autostart), ausgeführt von bin/etude-autostart.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var apps            // AppManager.qml

    spacing: 4

    Component.onCompleted: apps.refresh()

    // Apps, die noch nicht im Autostart sind
    readonly property var addable: apps.apps.filter(a => !apps.autostart.some(e => e.id === a.id))

    Item {
        width: root.width
        height: Math.max(introText.implicitHeight, addBtn.height) + 8
        Text {
            id: introText
            anchors.left: parent.left
            anchors.right: addBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            text: tr.t("startup.theseAppsStartAutomaticallyWhen")
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
        Button {
            id: addBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            iconStart: String.fromCodePoint(0xF0415)
            text: tr.t("startup.addApp")
            onClicked: { pick.value = ""; addDialog.open() }
        }
    }

    Text {
        visible: root.apps.error !== ""
        width: root.width
        wrapMode: Text.Wrap
        text: root.apps.error
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    Rectangle {
        visible: root.apps.autostart.length === 0
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: tr.t("startup.noStartupApps")
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
    }

    Repeater {
        model: root.apps.autostart
        SettingRow {
            id: row
            required property var modelData
            readonly property bool own: modelData.userPath !== "" && modelData.systemPath === ""
            width: root.width
            chevron: false
            icon: String.fromCodePoint(0xF003B)
            iconSource: root.apps.iconSource(modelData.icon)
            label: modelData.name
            desc: I18n.t(modelData.enabled ? "common.on" : "common.off") + " · " + tr.t(row.own ? "startup.addedByYou" : "startup.system")

            Item {
                visible: row.own
                width: delBtn.width; height: delBtn.height
                anchors.verticalCenter: parent.verticalCenter
                Button {
                    id: delBtn
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(0xF0A7A)
                    onClicked: root.apps.removeAutostart(row.modelData)
                }
                Tooltip { text: tr.t("startup.removeFromStartup"); shown: delBtn.hovered }
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: row.modelData.enabled
                onToggled: root.apps.setAutostart(row.modelData, !row.modelData.enabled)
            }
        }
    }

    Dialog {
        id: addDialog
        title: tr.t("startup.addAnAppToStartup")
        description: tr.t("startup.theAppThenStartsEvery")
        Field {
            width: parent.width
            label: tr.t("startup.app")
            Select {
                id: pick
                width: parent.width
                searchable: true
                placeholder: tr.t("startup.chooseAnApp")
                model: root.addable.map(a => ({ value: a.id, label: a.name }))
                onActivated: (v) => pick.value = v
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: I18n.t("common.add")
                enabled: pick.value !== ""
                onClicked: {
                    const a = root.apps.appById(pick.value)
                    if (a) root.apps.addAutostart(a)
                    addDialog.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: addDialog.close() }
        }
    }
}
