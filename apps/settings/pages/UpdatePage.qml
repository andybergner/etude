import QtQuick
import Quickshell
import Etude.Ui
import "../components"

// Etude Update (wie Windows Update): Status mit Hauptbutton, darunter Etude-Updates,
// Systemupdates (Arch) und die Ausgabe der letzten Installation.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var updates          // Updates.qml

    spacing: 4

    Component.onCompleted: updates.autoCheck()

    function g(cp) { return String.fromCodePoint(cp) }
    function pretty(name) {
        return name === "etude" ? "Etude" : name === "etude-ui" ? "Etude UI" : name
    }
    function lastCheckText() {
        const t = updates.lastCheck
        if (!t) return tr.t("update.neverChecked")
        const d = new Date(t)
        const today = new Date().toDateString() === d.toDateString()
        return tr.t("update.lastChecked").arg(today ? tr.t("update.todayAt").arg(d.toLocaleTimeString(I18n.locale, Locale.ShortFormat))
                                                    : d.toLocaleString(I18n.locale, Locale.ShortFormat))
    }
    function errorText() {
        const e = updates.error
        return e === "locked" ? tr.t("update.pacmanBusy")
             : e === "denied" ? tr.t("update.notAuthorized")
             : e
    }

    // Zustand der Statuskarte
    readonly property string mode: updates.state === "checking" ? "checking"
                                 : updates.state === "installing" ? "installing"
                                 : updates.error ? "error"
                                 : updates.etudeUpdates.length > 0 ? "etude"
                                 : updates.systemUpdates.length > 0 ? "system"
                                 : updates.lastCheck > 0 ? "current" : "unknown"

    // ===== Entwicklungsmodus =====
    Rectangle {
        visible: root.updates.dev
        width: root.width
        height: devText.implicitHeight + 24
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.primary, 0.08)
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.3)
        Text {
            id: devIcon
            x: 16; y: 12
            text: root.g(0xF0169)
            color: Theme.primary
            font.family: Theme.fontIcon; font.pixelSize: 18
        }
        Text {
            id: devText
            anchors.left: devIcon.right; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 16
            y: 12
            wrapMode: Text.Wrap
            text: tr.t("update.devMode").arg(root.updates.devVersion)
            color: Theme.foreground
            font.family: Theme.fontSans; font.pixelSize: 13
        }
    }

    // ===== Status =====
    Rectangle {
        width: root.width
        height: Math.max(96, statusCol.implicitHeight + 36)
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Rectangle {
            id: badge
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 52; height: 52
            radius: 26
            readonly property color tone: root.mode === "error" ? Theme.destructive
                                        : root.mode === "etude" || root.mode === "system" ? Theme.primary
                                        : root.mode === "current" ? Theme.success
                                        : Theme.mutedForeground
            color: Theme.alpha(tone, 0.15)
            Text {
                id: badgeIcon
                anchors.centerIn: parent
                text: root.g(root.mode === "checking" || root.mode === "installing" ? 0xF0453     // sync
                           : root.mode === "error" ? 0xF0026                                       // alert
                           : root.mode === "current" ? 0xF05E0                                     // check-circle
                           : 0xF06B0)                                                              // update
                color: badge.tone
                font.family: Theme.fontIcon; font.pixelSize: 26
                RotationAnimation on rotation {
                    running: root.updates.busy
                    from: 0; to: 360; duration: 1200; loops: Animation.Infinite
                    onRunningChanged: if (!running) badgeIcon.rotation = 0
                }
            }
        }
        Column {
            id: statusCol
            anchors.left: badge.right
            anchors.leftMargin: 16
            anchors.right: actions.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: root.mode === "checking" ? tr.t("update.checking")
                    : root.mode === "installing" ? tr.t("update.installing")
                    : root.mode === "error" ? tr.t("update.somethingWentWrong")
                    : root.mode === "etude" ? tr.tn("update.etudeAvailable", root.updates.etudeUpdates.length).arg(root.updates.etudeUpdates.length)
                    : root.mode === "system" ? tr.t("update.etudeCurrentSystemAvailable")
                    : root.mode === "current" ? tr.t("update.upToDate")
                    : tr.t("update.notCheckedYet")
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 17; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: root.mode === "error" ? root.errorText()
                    : root.mode === "installing" ? tr.t("update.installingHint")
                    : root.lastCheckText()
                color: root.mode === "error" ? Theme.destructive : Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 13
            }
        }
        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Button {
                visible: root.mode === "etude"
                text: tr.t("update.installNow")
                iconStart: root.g(0xF01DA)
                enabled: !root.updates.busy
                onClicked: root.updates.installEtude()
            }
            Button {
                visible: root.mode !== "etude" && root.mode !== "installing"
                variant: root.mode === "unknown" || root.mode === "error" ? "default" : "outline"
                text: root.mode === "error" ? tr.t("update.tryAgain") : tr.t("update.checkForUpdates")
                iconStart: root.g(0xF0450)
                enabled: !root.updates.busy
                onClicked: root.updates.check()
            }
        }
    }

    // ===== Hinweise nach der Installation =====
    Rectangle {
        visible: root.updates.needsSystem
        width: root.width
        height: nsCol.implicitHeight + 28
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.warning, 0.1)
        border.width: 1
        border.color: Theme.alpha(Theme.warning, 0.35)
        Column {
            id: nsCol
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.right: nsBtn.left; anchors.rightMargin: 16
            y: 14
            spacing: 2
            Text {
                text: tr.t("update.needsSystemTitle")
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: tr.t("update.needsSystemDesc").arg(root.updates.needsSystemPkgs)
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 13
            }
        }
        Button {
            id: nsBtn
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: tr.t("update.updateEverything")
            enabled: !root.updates.busy
            onClicked: root.updates.installSystem()
        }
    }
    Rectangle {
        visible: root.updates.needsRelogin || root.updates.rebootRecommended
        width: root.width
        height: 52
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.success, 0.1)
        border.width: 1
        border.color: Theme.alpha(Theme.success, 0.35)
        Text {
            id: okIcon
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.g(root.updates.rebootRecommended ? 0xF0709 : 0xF0343)
            color: Theme.success
            font.family: Theme.fontIcon; font.pixelSize: 18
        }
        Text {
            anchors.left: okIcon.right; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.updates.rebootRecommended ? tr.t("update.restartRecommended") : tr.t("update.signInAgain")
            color: Theme.foreground
            font.family: Theme.fontSans; font.pixelSize: 13
        }
    }

    // ===== Etude =====
    SectionTitle { text: "Etude" }

    Repeater {
        model: root.updates.etudeUpdates
        SettingRow {
            required property var modelData
            width: root.width
            icon: root.g(modelData.name === "etude-ui" ? 0xF03D8 : 0xF03D7)       // palette / package
            label: root.pretty(modelData.name)
            desc: tr.t("update.fromTo").arg(modelData.old).arg(modelData.new)
            chevron: false
            Button {
                visible: root.updates.changesUrl(modelData) !== ""
                variant: "link"
                size: "sm"
                text: tr.t("update.whatsNew")
                onClicked: Quickshell.execDetached(["xdg-open", root.updates.changesUrl(modelData)])
            }
        }
    }
    SettingRow {
        visible: root.updates.etudeUpdates.length === 0
        width: root.width
        icon: root.g(0xF03D7)
        label: (root.updates.installed["etude"] ? "Etude " + root.updates.installed["etude"] : "Etude –")
               + "  ·  " + (root.updates.installed["etude-ui"] ? "Etude UI " + root.updates.installed["etude-ui"] : "Etude UI –")
        desc: root.updates.installed["etude"] ? tr.t("update.installedVersions") : tr.t("update.notInstalledAsPackage")
        chevron: false
    }

    // ===== System (Arch Linux) =====
    SectionTitle { text: tr.t("update.systemUpdates") }

    Expander {
        width: root.width
        icon: root.g(0xF08C7)
        label: root.updates.systemUpdates.length > 0
               ? tr.tn("update.systemAvailable", root.updates.systemUpdates.length).arg(root.updates.systemUpdates.length)
               : tr.t("update.systemCurrent")
        desc: tr.t("update.systemDesc")

        Column {
            width: parent.width
            topPadding: 4
            bottomPadding: 12
            spacing: 0
            Repeater {
                model: root.updates.systemUpdates
                Item {
                    required property var modelData
                    width: parent.width
                    height: 28
                    Text {
                        x: 56
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.45 - 56
                        elide: Text.ElideRight
                        text: modelData.name
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.5
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: modelData.old + "  →  " + modelData.new
                        color: Theme.mutedForeground
                        font.family: Theme.fontMono; font.pixelSize: 12
                    }
                }
            }
            Item {
                visible: root.updates.systemUpdates.length > 0
                width: parent.width
                height: 48
                Button {
                    anchors.right: parent.right; anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: tr.t("update.updateEverything")
                    iconStart: root.g(0xF01DA)
                    enabled: !root.updates.busy
                    onClicked: root.updates.installSystem()
                }
            }
        }
    }

    // ===== Ausgabe der letzten Installation =====
    Expander {
        visible: root.updates.log !== ""
        width: root.width
        icon: root.g(0xF018D)
        label: tr.t("update.details")
        desc: tr.t("update.detailsDesc")
        expanded: root.updates.busy

        Rectangle {
            x: 16
            width: parent.width - 32
            height: Math.min(260, logText.implicitHeight + 20)
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.foreground, 0.04)
            Flickable {
                id: logFlick
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentHeight: logText.implicitHeight
                onContentHeightChanged: if (contentHeight > height) contentY = contentHeight - height
                TextEdit {
                    id: logText
                    width: logFlick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.WrapAnywhere
                    text: root.updates.log
                    color: Theme.foreground
                    font.family: Theme.fontMono; font.pixelSize: 12
                }
            }
        }
        Item { width: 1; height: 12 }
    }
}
