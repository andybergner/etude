import QtQuick
import Etude.Ui
import "../components"

// Konten › Anmeldeoptionen (wie Windows): Kennwort ändern (im Dialog), Sperrbildschirm
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var account       // Account.qml
    signal navigate(string path)

    spacing: 4

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF07F5)
        label: tr.t("account.password")
        desc: tr.t("account.youUseThePasswordTo")
        Button {
            id: changeBtn
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("account.change")
            onClicked: {
                oldPw.text = ""; newPw.text = ""; newPw2.text = ""
                root.account.error = ""; root.account.message = ""
                pop.open()
                oldPw.forceActiveFocus()
            }
        }
    }

    Dialog {
        id: pop
        title: tr.t("account.changePassword")
        description: tr.t("account.enterYourCurrentPasswordFirst")

        Field {
            width: parent.width
            label: tr.t("account.currentPassword")
            error: root.account.error === tr.t("account.theCurrentPasswordIsIncorrect") ? root.account.error : ""
            Input { id: oldPw; width: parent.width; echoMode: TextInput.Password; onAccepted: newPw.forceActiveFocus() }
        }
        Field {
            width: parent.width
            label: tr.t("account.newPassword")
            hint: tr.t("account.atLeast8Characters")
            error: newPw.text !== "" && newPw.text.length < 8 ? tr.t("account.atLeast8Characters") : ""
            Input { id: newPw; width: parent.width; echoMode: TextInput.Password; onAccepted: newPw2.forceActiveFocus() }
        }
        Field {
            width: parent.width
            label: tr.t("account.confirmPassword")
            error: newPw2.text !== "" && newPw.text !== newPw2.text ? tr.t("account.thePasswordsDontMatch") : ""
            Input { id: newPw2; width: parent.width; echoMode: TextInput.Password; onAccepted: saveBtn.clicked() }
        }

        Text {
            visible: root.account.error !== "" && root.account.error !== tr.t("account.theCurrentPasswordIsIncorrect")
            width: parent.width
            text: root.account.error
            wrapMode: Text.Wrap
            color: Theme.destructive
            font.family: Theme.fontSans
            font.pixelSize: 12
        }

        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                id: saveBtn
                text: root.account.busy ? tr.t("account.changing") : tr.t("account.changePassword")
                enabled: !root.account.busy && oldPw.text !== "" && newPw.text.length >= 8 && newPw.text === newPw2.text
                onClicked: root.account.changePassword(oldPw.text, newPw.text)
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: pop.close() }
        }
    }

    // nach Erfolg schließen und Felder leeren
    Connections {
        target: root.account
        function onMessageChanged() {
            if (root.account.message === tr.t("account.passwordChanged")) { pop.close(); oldPw.text = ""; newPw.text = ""; newPw2.text = "" }
        }
    }

    SectionTitle { text: tr.t("account.moreSettings") }

    SettingRow {
        width: root.width
        icon: String.fromCodePoint(0xF033E)
        label: tr.t("account.lockScreenAutomatically")
        desc: tr.t("account.timesUnderSystemPowerBattery")
        onClicked: root.navigate("system/power")
    }
}
