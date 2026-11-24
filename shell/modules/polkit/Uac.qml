// Benutzerkontensteuerung (wie Windows-UAC): eigener Polkit-Agent.
// Wenn eine App Administratorrechte braucht (pkexec, Systemeinstellungen …), dunkelt
// der Bildschirm ab und in der Mitte erscheint die Abfrage mit Benutzername und Kennwort.
// Es darf nur EIN Polkit-Agent laufen (polkit-gnome, polkit-kde-agent … vorher beenden).
//
// Abstände wie shadcn/ui Dialog: p-6 (24), gap-4 (16) zwischen den Blöcken,
// gap-2 (8) zwischen Titel und Beschreibung, Formularfelder über Field (Label oben).
//
// Wird aus shell.qml über einen LazyLoader geladen: Fehlt Quickshell.Services.Polkit,
// läuft der Rest der Shell trotzdem.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import QtQuick
import Etude.Ui

Scope {
    id: root
    property Translations tr: Translations { domain: "polkit" }   // Texte dieses Moduls

    readonly property string user: Quickshell.env("USER") || ""

    PolkitAgent {
        id: agent
        // Die Anmeldung bei polkitd läuft asynchron
        onIsRegisteredChanged: if (isRegistered) console.log("Etude UAC: polkit agent active")
    }
    Timer {
        running: true
        interval: 3000
        onTriggered: if (!agent.isRegistered) console.warn("Etude UAC: polkit agent not registered – is another agent running?")
    }

    readonly property var flow: agent.flow

    // pkexec: "… to run `/usr/bin/pacman -Rns foo' as the super user" → Befehl herauslösen
    readonly property string command: {
        if (!flow || flow.actionId !== "org.freedesktop.policykit.exec") return ""
        const m = flow.message || ""
        const r = m.match(/[`'"„»]([^`'"“«]+)[`'"“«]/)
        return r ? r[1].trim() : ""
    }
    readonly property string program: {
        if (command === "") return ""
        const p = command.split(/\s+/)[0]
        return p.slice(p.lastIndexOf("/") + 1)
    }

    // Konten, die sich als Administrator anmelden dürfen (polkit-Identitäten)
    readonly property var identities: flow && flow.identities ? flow.identities : []
    // Identity (Quickshell): id (uid/gid), string ("unix-user:andy"), displayName, isGroup
    function loginOf(i) {
        const str = i ? String(i.string || "") : ""
        return str.indexOf(":") >= 0 ? str.slice(str.indexOf(":") + 1) : str
    }
    function nameOf(i) {
        if (!i) return ""
        const login = loginOf(i), dn = String(i.displayName || "")
        return dn && dn !== login ? dn + " (" + login + ")" : (login || dn)
    }
    // passt die Eingabe zu einer Identität? ("andy", "Andy Bergner" oder "Andy Bergner (andy)")
    function findIdentity(u) {
        const q = u.trim().toLowerCase()
        if (q === "") return null
        for (const i of identities) {
            if (i.isGroup) continue
            const login = loginOf(i).toLowerCase()
            const dn = String(i.displayName || "").toLowerCase()
            if (q === login || q === dn || q === nameOf(i).toLowerCase() || q === String(i.id)) return i
        }
        return null
    }

    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor
        const s = Quickshell.screens
        for (let i = 0; i < s.length; i++) if (m && s[i].name === m.name) return s[i]
        return s.length > 0 ? s[0] : null
    }

    PanelWindow {
        id: win
        screen: root.focusedScreen
        visible: agent.isActive && root.flow !== null
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etude-uac"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property bool showDetails: false
        property string error: ""
        property string pending: ""          // Kennwort, das nach dem Kontowechsel gesendet wird

        onVisibleChanged: {
            if (!visible) return
            showDetails = false; error = ""; pending = ""
            pw.text = ""
            userInput.text = root.user
            focusTimer.restart()
        }
        Timer { id: focusTimer; interval: 50; onTriggered: pw.forceActiveFocus() }

        function yes() {
            if (!root.flow) return
            if (userInput.text.trim() === "") { userInput.forceActiveFocus(); return }
            if (pw.text === "") { pw.forceActiveFocus(); return }
            win.error = ""
            // anderes Konto eingegeben → Identität wechseln, Kennwort danach senden
            if (root.identities.length > 0) {
                const id = root.findIdentity(userInput.text)
                if (!id) {
                    const allowed = root.identities.map(i => root.nameOf(i)).join(", ")
                    win.error = root.tr.t("polkit.notAllowed").arg(userInput.text.trim()) + (allowed ? " " + root.tr.t("polkit.allowed").arg(allowed) : "")
                    shake.restart()
                    userInput.forceActiveFocus()
                    return
                }
                if (id !== root.flow.selectedIdentity) {
                    win.pending = pw.text
                    root.flow.selectedIdentity = id
                    return
                }
            }
            if (root.flow.isResponseRequired) root.flow.submit(pw.text)
            else win.pending = pw.text
        }
        function no() { if (root.flow) root.flow.cancelAuthenticationRequest() }

        Connections {
            target: root.flow
            ignoreUnknownSignals: true
            function onIsResponseRequiredChanged() {
                if (root.flow.isResponseRequired && win.pending !== "") {
                    const p = win.pending
                    win.pending = ""
                    root.flow.submit(p)
                }
            }
            function onAuthenticationFailed() {
                win.error = root.tr.t("polkit.wrongCredentials")
                win.pending = ""
                pw.text = ""
                shake.restart()
                pw.forceActiveFocus()
            }
        }

        // abgedunkelter Bildschirm (sicherer Desktop)
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        }

        FocusRoot {                              // Tastatur wie bei Windows (Pfeile, Enter, Fokus-Ring)
            anchors.fill: parent
        // ===== Karte =====
        Rectangle {
            id: card
            width: Math.min(460, parent.width - 32)
            height: col.implicitHeight
            anchors.centerIn: parent
            radius: Theme.radiusXl
            color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
            border.width: 1
            border.color: Theme.border

            transform: Translate { id: shakeT; x: 0 }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeT; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50 }
            }

            // gleichmäßiger Schatten
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    z: -1
                    anchors.fill: parent
                    anchors.margins: -(index + 1)
                    radius: card.radius + index + 1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.25 * (1 - index / 6))
                }
            }

            Column {
                id: col
                width: parent.width

                // ---- Kopf: Benutzerkontensteuerung ----
                Rectangle {
                    width: parent.width
                    height: 40
                    color: Theme.alpha(Theme.primary, 0.12)
                    topLeftRadius: card.radius
                    topRightRadius: card.radius
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(0xF0498)
                            color: Theme.primary
                            font.family: Theme.fontIcon; font.pixelSize: 16
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.tr.t("polkit.title")
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                        }
                    }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }
                }

                // ---- Inhalt: p-6, gap-4 ----
                Column {
                    x: 24
                    width: parent.width - 48
                    topPadding: 24
                    bottomPadding: 24
                    spacing: 16

                    // Kopf (gap-2): Titel + Beschreibung
                    Column {
                        width: parent.width
                        spacing: 8
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: root.tr.t("polkit.question")
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 18; font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: root.tr.t("polkit.signInAdmin")
                            color: Theme.mutedForeground
                            font.family: Theme.fontSans; font.pixelSize: 14
                        }
                    }

                    // App (gap-3) + Details
                    Column {
                        width: parent.width
                        spacing: 8
                        Row {
                            width: parent.width
                            spacing: 12
                            Rectangle {
                                width: 40; height: 40
                                radius: Theme.radiusLg
                                color: Theme.muted
                                Image {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    width: 24; height: 24
                                    source: root.flow && root.flow.iconName ? Quickshell.iconPath(root.flow.iconName, true) : ""
                                    sourceSize: Qt.size(48, 48)
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: String.fromCodePoint(0xF0493)
                                    color: Theme.foreground
                                    font.family: Theme.fontIcon; font.pixelSize: 20
                                }
                            }
                            Column {
                                width: parent.width - 52
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: root.program !== "" ? root.program : root.tr.t("polkit.systemAction")
                                    color: Theme.foreground
                                    font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                                }
                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    text: root.command !== "" ? root.tr.t("polkit.runAsAdmin") : (root.flow ? root.flow.message : "")
                                    color: Theme.mutedForeground
                                    font.family: Theme.fontSans; font.pixelSize: 12
                                }
                            }
                        }
                        Text {
                            text: root.tr.t(win.showDetails ? "polkit.hideDetails" : "polkit.showDetails") + " " + String.fromCodePoint(win.showDetails ? 0xF0143 : 0xF0140)
                            color: Theme.primary
                            font.family: Theme.fontSans; font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.showDetails = !win.showDetails
                            }
                        }
                        Rectangle {
                            visible: win.showDetails
                            width: parent.width
                            height: details.implicitHeight + 24
                            radius: Theme.radiusMd
                            color: Theme.muted
                            Text {
                                id: details
                                x: 12; y: 12
                                width: parent.width - 24
                                wrapMode: Text.WrapAnywhere
                                text: (root.command !== "" ? root.tr.t("polkit.command").arg(root.command) + "\n" : "") +
                                      root.tr.t("polkit.action").arg(root.flow ? root.flow.actionId : "")
                                color: Theme.mutedForeground
                                font.family: Theme.fontMono; font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border }

                    // Formular (gap-4 zwischen den Feldern, Label oben)
                    Column {
                        width: parent.width
                        spacing: 16
                        Field {
                            width: parent.width
                            label: root.tr.t("polkit.userName")
                            Input {
                                id: userInput
                                width: parent.width
                                iconStart: String.fromCodePoint(0xF0004)
                                onAccepted: pw.forceActiveFocus()
                                onEscapePressed: win.no()
                            }
                        }
                        Field {
                            width: parent.width
                            label: root.tr.t("polkit.password")
                            error: win.error !== "" ? win.error
                                 : (root.flow && root.flow.supplementaryIsError ? root.flow.supplementaryMessage : "")
                            hint: root.flow && !root.flow.supplementaryIsError ? (root.flow.supplementaryMessage || "") : ""
                            Input {
                                id: pw
                                width: parent.width
                                echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                                iconStart: String.fromCodePoint(0xF0306)
                                onAccepted: win.yes()
                                onEscapePressed: win.no()
                            }
                        }
                    }

                    // Fuß (gap-2)
                    Row {
                        width: parent.width
                        spacing: 8
                        Button {
                            width: (parent.width - 8) / 2
                            text: I18n.t("common.yes")
                            enabled: !!root.flow && win.pending === ""
                            onClicked: win.yes()
                        }
                        Button {
                            width: (parent.width - 8) / 2
                            variant: "outline"
                            text: I18n.t("common.no")
                            onClicked: win.no()
                        }
                    }
                }
            }
        }
        }
    }
}
