import QtQuick
import Etude.Ui
import "../components"
import "../Nav.js" as Nav

// Konten (Aufbau wie Windows 11): großes Profilbild mit Name oben, darunter die Unterpunkte
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var account       // Account.qml
    signal navigate(string path)

    spacing: 4

    Component.onCompleted: account.refresh()

    Item {
        width: root.width
        height: 136
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20
            Avatar {
                size: 104
                name: root.account.displayName
                source: root.account.hasFace ? "file://" + root.account.facePath + "#" + root.account.faceVersion : ""
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: root.account.displayName
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.account.user + "  ·  " + tr.t("settings.localAccount")
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
                Text {
                    visible: root.account.isAdmin
                    text: tr.t("accounts.administrator")
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }
        }
    }

    Repeater {
        model: Nav.pagesT(tr, "accounts")
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate("accounts/" + modelData.id)
        }
    }

    Text {
        visible: !root.account.hasAccountsService
        width: root.width
        topPadding: 12
        text: tr.t("accounts.nameAndPasswordNeedAccountsservice")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
