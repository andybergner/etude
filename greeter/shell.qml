//@ pragma AppId com.etude.greeter
// Achtung: im Kopf (bis zum letzten import) keine geschweiften Klammern, auch nicht in Kommentaren –
// Quickshell liest die imports sonst nicht (scripts/qml-headercheck.py prüft das).
// Etude-Anmeldebildschirm für greetd – dieselbe Oberfläche wie der Sperrbildschirm.
// Läuft als Nutzer „greeter“ in einem eigenen kleinen Hyprland (default/greeter/hyprland.lua).
// Teilt sich die Oberfläche mit dem Sperrbildschirm über das Modul Etude.Lock (qml/Etude/Lock).
// Kein Zugriff auf ../shell – Quickshell lädt Dateien nur aus dem eigenen Ordner.
//
// Aussehen:  /etc/etude/greeter/appearance.json (dark, accent, wallpaperMode, wallpaperColor, wallpaper)
//            (Einstellungen › Personalisierung › Hintergrund › „Für den Anmeldebildschirm übernehmen“)
// Zuletzt angemeldeter Nutzer: /var/lib/etude-greeter/last-user
// Vorschau ohne greetd:  timeout 20 qs -p $ETUDE_HOME/greeter   (Anmelden geht dann nicht)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Etude.Ui
import Etude.Services
import Etude.Lock

ShellRoot {
    id: root

    readonly property string etcDir: "/etc/etude/greeter"
    readonly property string stateDir: "/var/lib/etude-greeter"

    // ---- Aussehen (systemweit, nicht aus dem Nutzerprofil) ----
    property var look: ({})
    readonly property string wallpaper: look.wallpaperMode === "image" && look.wallpaper ? "file://" + look.wallpaper : ""
    readonly property color tint: look.wallpaperColor || "#18181b"
    FileView {
        path: root.etcDir + "/appearance.json"
        printErrors: false
        onLoaded: { try { root.look = JSON.parse(text()) || {} } catch (e) { root.look = {} } root.applyTheme() }
        onLoadFailed: root.applyTheme()
    }
    function applyTheme() {
        Theme.followSystem = false
        Theme.wantDark = look.dark !== undefined ? !!look.dark : true
        Theme.wantBrand = look.accent || "transparent"
        Theme.wantTransparency = true
    }

    // ---- Nutzer: echte Konten (UID 1000–59999, mit Login-Shell) ----
    property var users: []
    property int userIndex: 0
    property string lastUser: ""
    property string otherName: ""        // „Anderer Benutzer“: eingetippter Name (userIndex === users.length)
    property bool usersLoaded: false
    // „Anderer Benutzer“ und die Nutzerliste unten links nur, wenn es etwas zu wählen gibt:
    // mehrere Konten oder Domäne/Arbeitsgruppe (sssd/realmd – Konten, die nicht in /etc/passwd stehen).
    // Ein einziges lokales Konto: keine Auswahl (wie Windows).
    property bool domainJoined: false
    Process {
        running: true
        command: ["sh", "-c", "[ -e /etc/sssd/sssd.conf ] || { command -v realm >/dev/null && realm list 2>/dev/null | grep -q .; }"]
        onExited: (code) => { root.domainJoined = code === 0; root.pickLastUser() }
    }
    readonly property bool allowOther: domainJoined || (usersLoaded && users.length !== 1)
    readonly property bool otherSelected: usersLoaded && allowOther && userIndex >= users.length
    Process {
        running: true
        command: ["sh", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 \":\" $5 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of this.text.split("\n")) {
                    if (!line) continue
                    const i = line.indexOf(":")
                    const name = line.slice(0, i)
                    list.push({ name: name, realName: line.slice(i + 1).split(",")[0], avatar: "file:///var/lib/AccountsService/icons/" + name })
                }
                root.users = list
                root.usersLoaded = true
                root.pickLastUser()
            }
        }
    }
    FileView {
        id: lastFile
        path: root.stateDir + "/last-user"
        printErrors: false
        onLoaded: { root.lastUser = text().trim(); root.pickLastUser() }
    }
    function pickLastUser() {
        if (!lastUser) return
        const i = users.findIndex(u => u.name === lastUser)
        if (i >= 0) userIndex = i
        else if (users.length > 0 && allowOther) { userIndex = users.length; otherName = lastUser }   // zuletzt: anderer Benutzer
    }
    function selectUser(i) {
        userIndex = i
        ctx.password = ""
        ctx.failed = false
        ctx.errorText = ""
    }

    GreeterContext {
        id: ctx
        user: root.otherSelected ? root.otherName.trim()
            : root.users.length > 0 ? root.users[Math.min(root.userIndex, root.users.length - 1)].name : ""
        onLoggedIn: (u) => lastFile.setText(u + "\n")
    }

    function power(action) {
        if (action === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
        else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (action === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
    }

    // Netzwerk und Akku für die Symbole unten rechts
    Network { id: net }
    Battery { id: bat }
    readonly property string netIcon: StatusIcons.network(net.kind, net.signal)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // eine Fläche pro Monitor; Tastatur auf dem ersten
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "etude-greeter"
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

            LockSurface {
                anchors.fill: parent
                context: ctx
                now: clock.date
                wallpaper: root.wallpaper
                tint: root.tint
                users: root.users
                userIndex: root.userIndex
                allowOtherUser: root.allowOther
                otherSelected: root.otherSelected
                otherName: root.otherName
                onOtherNameEdited: (n) => { root.otherName = n; ctx.failed = false }
                networkKind: net.kind
                networkName: net.ssid
                readonly property var current: !root.otherSelected && root.users.length > 0 ? root.users[Math.min(root.userIndex, root.users.length - 1)] : null
                userName: current ? (current.realName || current.name) : ""
                avatar: current ? current.avatar : ""
                networkIcon: root.netIcon
                network: net                          // Klick aufs Symbol: Netzwerk-Menü
                batteryText: bat.present ? bat.level + " %" : ""
                batteryIcon: bat.present ? StatusIcons.battery(bat.level, bat.charging) : ""
                onUserSelected: (i) => root.selectUser(i)
                onPowerAction: (a) => root.power(a)
            }
        }
    }
}
