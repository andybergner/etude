import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Etude.Ui
import Etude.Menus

// Sperrbildschirm wie bei Windows 11 – zwei Ansichten:
//   1. Sperrbildschirm: Hintergrund, große Uhrzeit mit Datum, unten rechts Netzwerk/Akku.
//      Taste, Klick oder Wischen nach oben → schiebt sich nach oben weg.
//   2. Anmeldung: Hintergrund weichgezeichnet, großer Avatar, Name, Passwortfeld mit Pfeil,
//      unten rechts Netzwerk, Akku und Ein/Aus. Nach 30 s ohne Eingabe zurück zu 1.
//
// Modul Etude.Lock: dieselbe Oberfläche für Sperrbildschirm (shell) und Anmeldebildschirm (greeter).
// Beim Anmelden kommt die Prüfung
// von greetd statt PAM, und unten links steht die Nutzerauswahl (users, userIndex).
// context braucht: password, checking, failed, failCount, showLogin, submit(); optional errorText.
// Symbole für Netzwerk/Akku: StatusIcons.network(kind, signal), StatusIcons.battery(level, charging).
Item {
    id: root
    property Translations tr: Translations { domain: "lock" }   // Texte dieses Moduls

    required property var context        // LockContext.qml oder greeter/GreeterContext.qml
    property string wallpaper: ""
    property color tint: "#18181b"
    property string userName: Quickshell.env("USER") || ""
    property string avatar: ""
    property date now: new Date()
    property string networkIcon: ""
    property string networkKind: ""      // "wifi" | "ethernet" | "none" – für den Tooltip
    property string networkName: ""      // WLAN-Name – für den Tooltip
    property var network: null           // Etude.Services/Network: Klick aufs Symbol öffnet das Netzwerk-Menü
    property string batteryText: ""      // "" = kein Akku
    property string batteryIcon: ""

    property var users: []               // Anmeldebildschirm: [{ name, realName, avatar }]
    property int userIndex: 0
    // „Anderer Benutzer“ (nur Anmeldebildschirm): Benutzername selbst eintippen, z. B. für Konten,
    // die nicht in der Liste stehen. Gewählt ist er bei userIndex === users.length.
    property bool allowOtherUser: false
    property string otherName: ""
    property bool otherSelected: allowOtherUser && userIndex >= users.length

    signal powerAction(string action)   // "reboot" | "poweroff" | "suspend"
    signal userSelected(int index)      // index === users.length → „Anderer Benutzer“
    signal otherNameEdited(string name)

    // Feststelltaste (wie Windows: Hinweis unter dem Kennwortfeld)
    property bool capsLock: false
    Process {
        id: capsProc
        command: ["sh", "-c",
            "if out=$(hyprctl devices -j 2>/dev/null) && [ -n \"$out\" ]; then " +
            "printf '%s' \"$out\" | grep -q '\"capsLock\": *true' && echo 1 || echo 0; " +
            "else grep -qs 1 /sys/class/leds/*capslock*/brightness && echo 1 || echo 0; fi"]
        stdout: StdioCollector { onStreamFinished: root.capsLock = this.text.trim() === "1" }
    }
    Timer {
        interval: 500; repeat: true; triggeredOnStart: true
        running: root.login && root.visible
        onTriggered: if (!capsProc.running) capsProc.running = true
    }

    readonly property bool login: context.showLogin
    function g(cp) { return String.fromCodePoint(cp) }

    function openLogin(firstChar) {
        context.showLogin = true
        if (otherSelected && otherName === "") {
            if (firstChar) otherNameEdited(firstChar)
            nameInput.forceActiveFocus()
        } else {
            if (firstChar) context.password = firstChar
            input.forceActiveFocus()
        }
        backTimer.restart()
    }
    function focusField() {
        if (otherSelected && otherName === "") nameInput.forceActiveFocus()
        else input.forceActiveFocus()
    }

    // ===== Hintergrund (in der Anmeldung weichgezeichnet und dunkler) =====
    Rectangle { anchors.fill: parent; color: root.tint }
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: root.login ? 0.9 : 0
        brightness: root.login ? -0.15 : 0
        Behavior on blur { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on brightness { NumberAnimation { duration: 350 } }
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.login ? 0.35 : 0.15
        Behavior on opacity { NumberAnimation { duration: 350 } }
    }

    // ===== 1. Sperrbildschirm: Uhr =====
    Item {
        id: cover
        width: parent.width
        height: parent.height
        y: root.login ? -parent.height * 0.25 : 0
        opacity: root.login ? 0 : 1
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.14
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: "white"
                font.family: Theme.fontSans
                font.pixelSize: 112
                font.weight: Font.DemiBold
                font.letterSpacing: -2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.locale.toString(root.now, root.tr.t("lock.dateFormat"))
                color: "white"
                font.family: Theme.fontSans
                font.pixelSize: 22
                font.weight: Font.Medium
            }
        }

        // Wischen nach oben oder Klick öffnet die Anmeldung
        MouseArea {
            anchors.fill: parent
            property real startY: 0
            onPressed: (m) => startY = m.y
            onReleased: (m) => root.openLogin("")
        }
    }

    // ===== 2. Anmeldung =====
    Column {
        id: loginBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.3 + (root.login ? 0 : 40)
        spacing: 16
        opacity: root.login ? 1 : 0
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 300 } }

        // großer runder Avatar (wie Windows)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 176; height: 176
            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.15)
                Text {
                    anchors.centerIn: parent
                    visible: avatarImg.status !== Image.Ready || root.otherSelected
                    text: root.otherSelected ? root.g(0xF0004)            // account (Anderer Benutzer)
                        : root.userName ? root.userName.charAt(0).toUpperCase() : "?"
                    color: "white"
                    font.family: root.otherSelected ? Theme.fontIcon : Theme.fontSans
                    font.pixelSize: root.otherSelected ? 96 : 72
                    font.weight: Font.Light
                }
            }
            Image {
                id: avatarImg
                anchors.fill: parent
                source: root.avatar
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(352, 352)
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: avatarImg
                visible: avatarImg.status === Image.Ready && !root.otherSelected
                maskEnabled: true
                maskSource: avatarMask
            }
            Item {
                id: avatarMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: width / 2 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.otherSelected ? root.tr.t("lock.otherUser") : root.userName
            color: "white"
            font.family: Theme.fontSans
            font.pixelSize: 28
            font.weight: Font.Medium
        }

        // Benutzername (nur „Anderer Benutzer“)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.otherSelected
            width: 300
            height: 40
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: nameInput.activeFocus ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.25)
            }
            TextInput {
                id: nameInput
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                font.family: Theme.fontSans
                font.pixelSize: 15
                clip: true
                readOnly: root.context.checking
                text: root.otherName
                activeFocusOnTab: root.otherSelected
                onTextChanged: { if (root.otherName !== text) root.otherNameEdited(text); backTimer.restart() }
                Keys.onReturnPressed: input.forceActiveFocus()
                Keys.onEnterPressed: input.forceActiveFocus()
                Keys.onEscapePressed: root.context.showLogin = false
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: nameInput.text === ""
                    text: root.tr.t("lock.userName")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font: nameInput.font
                }
            }
        }

        // Passwortfeld mit Pfeil-Button (wie Windows)
        Item {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 40

            property real shake: 0
            transform: Translate { x: field.shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: field; property: "shake"; to: -12; duration: 50 }
                NumberAnimation { target: field; property: "shake"; to: 12;  duration: 80 }
                NumberAnimation { target: field; property: "shake"; to: -8;  duration: 70 }
                NumberAnimation { target: field; property: "shake"; to: 6;   duration: 60 }
                NumberAnimation { target: field; property: "shake"; to: 0;   duration: 50 }
            }
            Connections {
                target: root.context
                function onFailCountChanged() { shakeAnim.restart() }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.25)
            }

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: submit.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                activeFocusOnTab: true
                passwordCharacter: "●"
                color: "white"
                font.family: Theme.fontSans
                font.pixelSize: 15
                clip: true
                readOnly: root.context.checking
                text: root.context.password
                onTextChanged: { if (root.context.password !== text) root.context.password = text; backTimer.restart() }
                Keys.onReturnPressed: root.context.submit()
                Keys.onEnterPressed: root.context.submit()
                Keys.onEscapePressed: root.context.password === "" ? (root.context.showLogin = false) : (root.context.password = "")
                Keys.onPressed: (e) => { if (e.key === Qt.Key_CapsLock) capsProc.running = true }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: root.tr.t(root.context.checking ? "lock.checking" : "lock.password")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font: input.font
                }
            }

            // Pfeil → anmelden
            Rectangle {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                radius: Theme.radiusSm
                color: submitMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                visible: root.context.password !== "" && !root.context.checking
                Text {
                    anchors.centerIn: parent
                    text: root.g(0xF0054)                     // arrow-right
                    color: "white"
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                }
                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.context.submit()
                }
                Tooltip { text: root.tr.t(root.users.length > 0 || root.allowOtherUser ? "lock.signIn" : "lock.unlock"); shown: submitMouse.containsMouse }
            }
        }

        // Feststelltaste aktiv (wie Windows)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.capsLock
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.g(0xF0026)                             // alert
                color: "white"
                font.family: Theme.fontIcon
                font.pixelSize: 16
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.tr.t("lock.capsLock")
                color: "white"
                font.family: Theme.fontSans
                font.pixelSize: 13
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.context.failed
            width: Math.min(implicitWidth, 420)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: root.context.errorText || root.tr.t("lock.wrongPassword")
            color: "white"
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
    }

    // ===== unten links: andere Nutzer (nur Anmeldebildschirm, wie Windows) =====
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 4
        visible: root.login && (root.users.length > 1 || (root.allowOtherUser && root.users.length > 0))
        Repeater {
            model: root.users
            Item {
                id: userRow
                required property var modelData
                required property int index
                readonly property bool current: index === root.userIndex
                width: 240; height: 52
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: userRow.current ? Qt.rgba(1, 1, 1, 0.22) : userMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                }
                Rectangle {
                    id: miniAvatar
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34
                    radius: 17
                    color: Qt.rgba(1, 1, 1, 0.18)
                    clip: true
                    Text {
                        anchors.centerIn: parent
                        visible: miniImg.status !== Image.Ready
                        text: (userRow.modelData.realName || userRow.modelData.name).charAt(0).toUpperCase()
                        color: "white"
                        font.family: Theme.fontSans; font.pixelSize: 15
                    }
                    Image {
                        id: miniImg
                        anchors.fill: parent
                        source: userRow.modelData.avatar || ""
                        sourceSize: Qt.size(68, 68)
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                }
                Text {
                    anchors.left: miniAvatar.right; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: userRow.modelData.realName || userRow.modelData.name
                    color: "white"
                    font.family: Theme.fontSans; font.pixelSize: 14
                }
                MouseArea {
                    id: userMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.userSelected(userRow.index); root.focusField(); backTimer.restart() }
                }
            }
        }
        // „Anderer Benutzer“ (wie Windows)
        Item {
            id: otherRow
            visible: root.allowOtherUser
            width: 240; height: 52
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: root.otherSelected ? Qt.rgba(1, 1, 1, 0.22) : otherMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            }
            Rectangle {
                id: otherAvatar
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34
                radius: 17
                color: Qt.rgba(1, 1, 1, 0.18)
                Text {
                    anchors.centerIn: parent
                    text: root.g(0xF0004)
                    color: "white"
                    font.family: Theme.fontIcon; font.pixelSize: 20
                }
            }
            Text {
                anchors.left: otherAvatar.right; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.tr.t("lock.otherUser")
                color: "white"
                font.family: Theme.fontSans; font.pixelSize: 14
            }
            MouseArea {
                id: otherMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.userSelected(root.users.length); Qt.callLater(root.focusField); backTimer.restart() }
            }
        }
    }

    // ===== unten rechts: Netzwerk, Akku, Ein/Aus =====
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 18

        Text {
            visible: root.networkIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.networkIcon
            color: "white"
            font.family: Theme.fontIcon
            font.pixelSize: 22
            MouseArea {
                id: netMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: root.network ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.network) { netMenu.visible = !netMenu.visible; powerMenu.visible = false; backTimer.restart() }
            }
            Tooltip {
                text: root.networkKind === "wifi" ? root.tr.t("lock.wifi").arg(root.networkName)
                    : root.networkKind === "ethernet" ? root.tr.t("lock.ethernet") : root.tr.t("lock.offline")
                shown: netMouse.containsMouse && !netMenu.visible
            }
        }
        Item {
            visible: root.batteryText !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: batRow.implicitWidth; height: batRow.implicitHeight
            Row {
                id: batRow
                spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.batteryIcon; color: "white"; font.family: Theme.fontIcon; font.pixelSize: 22 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.batteryText; color: "white"; font.family: Theme.fontSans; font.pixelSize: 13 }
            }
            MouseArea { id: batMouse; anchors.fill: parent; hoverEnabled: true }
            Tooltip { text: root.tr.t("lock.battery").arg(root.batteryText); shown: batMouse.containsMouse }
        }
        // Ein/Aus nur in der Anmeldung (wie Windows)
        Item {
            visible: root.login
            width: 36; height: 36
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: powerMouse.containsMouse || powerMenu.visible ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: root.g(0xF0425)
                color: "white"
                font.family: Theme.fontIcon
                font.pixelSize: 22
            }
            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: powerMenu.visible = !powerMenu.visible
            }
            Tooltip {
                text: root.tr.t("lock.power")
                shown: powerMouse.containsMouse && !powerMenu.visible
                anchors.horizontalCenter: undefined
                anchors.right: parent.right                  // am Bildschirmrand nicht abschneiden
            }

            // kleines Menü über dem Knopf
            Rectangle {
                id: powerMenu
                visible: false
                anchors.right: parent.right
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                width: 200
                height: menuCol.implicitHeight + 8
                radius: Theme.radiusMd
                color: Qt.rgba(0.1, 0.1, 0.11, 0.92)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Column {
                    id: menuCol
                    x: 4; y: 4
                    width: parent.width - 8
                    Repeater {
                        model: [
                            { label: root.tr.t("lock.sleep"), action: "suspend",  icon: 0xF0594 },
                            { label: root.tr.t("lock.restart"), action: "reboot",   icon: 0xF0709 },
                            { label: root.tr.t("lock.shutDown"), action: "poweroff", icon: 0xF0425 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: menuCol.width
                            height: 34
                            radius: Theme.radiusSm
                            color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Text { text: root.g(modelData.icon); color: "white"; font.family: Theme.fontIcon; font.pixelSize: 15 }
                                Text { text: modelData.label; color: "white"; font.family: Theme.fontSans; font.pixelSize: 13 }
                            }
                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { powerMenu.visible = false; root.powerAction(modelData.action) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== Netzwerk-Menü (wie Windows: unten rechts über den Symbolen) =====
    MouseArea {                                  // Klick daneben schließt
        anchors.fill: parent
        visible: netMenu.visible
        onClicked: netMenu.visible = false
    }
    Loader {
        id: netMenu
        visible: false
        active: visible && root.network !== null
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 80
        sourceComponent: NetworkMenu {
            network: root.network
            showSettings: false
            MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }   // Klicks nicht durchreichen
        }
        Keys.onEscapePressed: visible = false
    }
    onNetworkChanged: if (!network) netMenu.visible = false

    // ===== Tastatur: jede Taste auf dem Sperrbildschirm öffnet die Anmeldung =====
    Item {
        id: keyCatcher
        focus: !root.login
        Keys.onPressed: (e) => {
            if (root.login) return
            // druckbares Zeichen gleich ins Passwortfeld übernehmen (wie Windows)
            root.openLogin(e.text && e.text.length === 1 && e.text >= " " ? e.text : "")
            e.accepted = true
        }
    }
    Component.onCompleted: keyCatcher.forceActiveFocus()

    onLoginChanged: {
        if (login) focusField()
        else { powerMenu.visible = false; netMenu.visible = false; keyCatcher.forceActiveFocus() }
    }

    // 30 s ohne Eingabe in der Anmeldung → zurück zur Uhr
    Timer {
        id: backTimer
        interval: 30000
        running: root.login
        onTriggered: if (!root.context.checking) { root.context.password = ""; root.context.showLogin = false }
    }
}
