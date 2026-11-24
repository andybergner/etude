import QtQuick
import Etude.Ui
import "../components"

// Konten › Andere Benutzer (wie Windows 11): Konto hinzufügen, Kontotyp ändern, entfernen.
// Läuft über AccountsService – die Benutzerkontensteuerung fragt nach dem Kennwort.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var account       // Account.qml

    spacing: 4

    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var others: account.users.filter(u => u.name !== account.user)
    readonly property var me: account.users.find(u => u.name === account.user) || null
    property var selected: null          // Benutzer für Kontotyp/Entfernen

    // ===== Konto hinzufügen =====
    SettingRow {
        width: root.width
        chevron: false
        icon: root.g(0xF0014)
        label: tr.t("account.addOtherUser")
        desc: tr.t("account.createASeparateAccountFor")
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: tr.t("account.addAccount")
            enabled: !root.account.busy
            onClicked: {
                userName.text = ""; fullName.text = ""; pw1.text = ""; pw2.text = ""; typeSel.value = "standard"
                root.account.error = ""; root.account.message = ""
                addDialog.open()
                fullName.forceActiveFocus()
            }
        }
    }

    Text {
        visible: root.account.error !== ""                // Erfolg kommt als Benachrichtigung
        width: root.width
        topPadding: 4
        wrapMode: Text.Wrap
        text: root.account.error
        color: Theme.destructive
        font.family: Theme.fontSans; font.pixelSize: 12
    }

    // ===== Dein Konto =====
    SectionTitle { text: tr.t("account.yourAccount") }
    SettingRow {
        visible: root.me !== null
        width: root.width
        chevron: false
        icon: root.g(0xF0004)
        label: root.me ? (root.me.realName || root.me.name) : ""
        desc: root.me ? root.me.name + " · " + (root.me.admin ? tr.t("account.administrator") : tr.t("account.standardUser")) : ""
    }

    // ===== Andere Benutzer =====
    SectionTitle { text: tr.t("account.otherUsers") }

    Rectangle {
        visible: root.others.length === 0
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: tr.t("account.thereAreNoOtherAccounts")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 13
        }
    }

    Repeater {
        model: root.others
        SettingRow {
            id: row
            required property var modelData
            width: root.width
            chevron: false
            icon: root.g(0xF0004)
            label: modelData.realName || modelData.name
            desc: modelData.name + " · " + (modelData.admin ? tr.t("account.administrator") : tr.t("account.standardUser"))
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "outline"
                size: "sm"
                text: tr.t("account.changeAccountType")
                enabled: !root.account.busy
                onClicked: { root.selected = row.modelData; typeSel2.value = row.modelData.admin ? "admin" : "standard"; typeDialog.open() }
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "destructive"
                size: "sm"
                text: I18n.t("common.remove")
                enabled: !root.account.busy
                onClicked: { root.selected = row.modelData; removeFiles.checked = false; removeDialog.open() }
            }
        }
    }

    // ===== Dialog: Konto hinzufügen =====
    Dialog {
        id: addDialog
        title: tr.t("account.addAccount")
        description: tr.t("account.theNewAccountCanThen")

        readonly property string nameErr: userName.text !== "" && !root.account.validUserName(userName.text)
            ? tr.t("account.lowercaseLettersDigitsAndStarts")
            : root.account.users.some(u => u.name === userName.text) ? tr.t("account.thatUserNameAlreadyExists2") : ""
        readonly property bool valid: userName.text !== "" && nameErr === "" && pw1.text.length >= 8 && pw1.text === pw2.text

        Field {
            width: parent.width
            label: tr.t("account.fullName")
            Input {
                id: fullName
                width: parent.width
                placeholder: tr.t("account.eGJaneDoe")
                onAccepted: userName.forceActiveFocus()
                // Benutzernamen vorschlagen, solange er nicht selbst geändert wurde
                onTextChanged: if (!userName.edited) userName.text = text.trim().split(/\s+/)[0].toLowerCase()
                    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss").replace(/[^a-z0-9_-]/g, "")
            }
        }
        Field {
            width: parent.width
            label: tr.t("account.userName")
            hint: tr.t("account.forSigningInLowercaseLetters")
            error: addDialog.nameErr
            Input {
                id: userName
                property bool edited: false
                width: parent.width
                onActiveFocusChanged: if (activeFocus) edited = true
                onAccepted: pw1.forceActiveFocus()
            }
        }
        Field {
            width: parent.width
            label: tr.t("account.password")
            error: pw1.text !== "" && pw1.text.length < 8 ? tr.t("account.atLeast8Characters") : ""
            Input { id: pw1; width: parent.width; echoMode: TextInput.Password; onAccepted: pw2.forceActiveFocus() }
        }
        Field {
            width: parent.width
            label: tr.t("account.confirmPassword")
            error: pw2.text !== "" && pw1.text !== pw2.text ? tr.t("account.thePasswordsDontMatch") : ""
            Input { id: pw2; width: parent.width; echoMode: TextInput.Password; onAccepted: createBtn.clicked() }
        }
        Field {
            width: parent.width
            label: tr.t("account.accountType")
            hint: typeSel.value === "admin" ? tr.t("account.canInstallAppsAndChange")
                                            : tr.t("account.forEverydayUseSystemChanges")
            Select {
                id: typeSel
                width: parent.width
                model: [{ value: "standard", label: tr.t("account.standardUser") }, { value: "admin", label: tr.t("account.administrator") }]
                value: "standard"
                onActivated: (v) => typeSel.value = v
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                id: createBtn
                text: tr.t("account.createAccount")
                enabled: addDialog.valid && !root.account.busy
                onClicked: {
                    if (!addDialog.valid) return
                    root.account.createUser(userName.text, fullName.text, pw1.text, typeSel.value === "admin")
                    pw1.text = ""; pw2.text = ""
                    addDialog.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: addDialog.close() }
        }
        onClosed: userName.edited = false
    }

    // ===== Dialog: Kontotyp ändern =====
    Dialog {
        id: typeDialog
        title: tr.t("account.changeAccountType")
        description: root.selected ? (root.selected.realName || root.selected.name) + " (" + root.selected.name + ")" : ""
        Field {
            width: parent.width
            label: tr.t("account.accountType")
            Select {
                id: typeSel2
                width: parent.width
                model: [{ value: "standard", label: tr.t("account.standardUser") }, { value: "admin", label: tr.t("account.administrator") }]
                onActivated: (v) => typeSel2.value = v
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: I18n.t("common.ok")
                onClicked: {
                    if (root.selected && (typeSel2.value === "admin") !== root.selected.admin)
                        root.account.setAdmin(root.selected, typeSel2.value === "admin")
                    typeDialog.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: typeDialog.close() }
        }
    }

    // ===== Dialog: Konto entfernen =====
    Dialog {
        id: removeDialog
        title: root.selected ? tr.t("account.removeQuestion").arg(root.selected.name) : ""
        description: tr.t("account.theAccountWillNoLonger")
        Item {
            width: parent.width
            height: Math.max(removeLabel.implicitHeight, removeFiles.height)
            Column {
                id: removeLabel
                anchors.left: parent.left
                anchors.right: removeFiles.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label { text: tr.t("account.deletePersonalFiles") }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.selected ? tr.t("account.deleteHomeDesc").arg(root.selected.name) : ""
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 12
                }
            }
            Switch {
                id: removeFiles
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onToggled: checked = !checked
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                variant: "destructive"
                text: removeFiles.checked ? tr.t("account.deleteAccountAndData") : tr.t("account.removeAccount")
                onClicked: { root.account.deleteUser(root.selected, removeFiles.checked); removeDialog.close() }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: removeDialog.close() }
        }
    }
}
