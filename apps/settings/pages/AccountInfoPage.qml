import QtQuick
import QtQuick.Dialogs
import Etude.Ui
import "../components"

// Konten › Ihre Infos (wie Windows): Profilbild ändern, Name ändern
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var account       // Account.qml

    spacing: 4

    // ===== Profilbild =====
    Item {
        width: root.width
        height: 200
        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            size: 160
            name: root.account.displayName
            source: root.account.hasFace ? "file://" + root.account.facePath + "#" + root.account.faceVersion : ""
        }
    }

    SectionTitle { text: tr.t("account.adjustYourPhoto"); topPadding: 0 }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF11E4)
        label: tr.t("account.chooseAFile")
        desc: tr.t("account.shownOnTheLockScreen")
        Button {
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("account.browseFiles")
            onClicked: dialog.open()
        }
        Button {
            visible: root.account.hasFace
            anchors.verticalCenter: parent.verticalCenter
            variant: "ghost"
            size: "sm"
            text: I18n.t("common.remove")
            onClicked: root.account.removeAvatar()
        }
    }

    // ===== Name =====
    SectionTitle { text: tr.t("account.accountInformation") }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0004)
        label: tr.t("account.fullName")
        desc: root.account.realName || tr.t("account.notSet")
        Button {
            id: nameBtn
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: I18n.t("common.edit")
            onClicked: { nameInput.text = root.account.realName; namePop.open(); nameInput.forceActiveFocus() }
        }
    }

    Dialog {
        id: namePop
        title: tr.t("account.changeName")
        description: tr.t("account.thisIsHowYouAppear")
        Field {
            width: parent.width
            label: tr.t("account.fullName")
            Input {
                id: nameInput
                width: parent.width
                placeholder: tr.t("account.firstAndLastName")
                onAccepted: saveBtn.clicked()
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                id: saveBtn
                text: I18n.t("common.save")
                enabled: nameInput.text.trim() !== "" && !root.account.busy
                onClicked: { root.account.setRealName(nameInput.text); namePop.close() }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: namePop.close() }
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0007)
        label: tr.t("account.userName")
        desc: tr.t("account.userNameFixed").arg(root.account.user)
    }

    Text {
        visible: root.account.error !== ""                // Erfolg kommt als Benachrichtigung
        width: root.width
        topPadding: 6
        text: root.account.error
        wrapMode: Text.Wrap
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    FileDialog {
        id: dialog
        title: tr.t("account.chooseAProfilePicture")
        nameFilters: [tr.t("account.imagesJpgJpegPngWebp")]
        onAccepted: root.account.setAvatar(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }
}
