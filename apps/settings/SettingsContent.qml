import QtQuick
import QtQuick.Layouts
import Etude.Ui
import "components"
import "pages"
import "Nav.js" as Nav

// Einstellungen: shadcn-Sidebar links, Kopfzeile mit Titel und Suche, Seite rechts.
// Reines QtQuick – Gerätedaten kommen von außen (shell.qml).
// Responsiv: schmale Fenster (gekachelt) klappen die Sidebar auf Icons ein.
Rectangle {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string userName: ""
    property string userDesc: tr.t("settings.localAccount")
    property string avatar: ""
    property var device: ({})
    property string hyprLayout: "scrolling"
    property var audio: null                // Etude.Services/Audio
    property var network: null              // Etude.Services/Network
    property var config: null               // Etude.Services/EtudeConfig
    property var timedate: null             // TimeDate.qml
    property var hypr: null                 // HyprSettings.qml
    property var storage: null              // Storage.qml
    property var battery: null              // Etude.Services/Battery
    property var power: null                // Etude.Services/PowerProfile
    property var bluetooth: null            // Etude.Services/Bluetooth
    property var displays: null             // Displays.qml
    property var brightness: null           // Etude.Services/Brightness
    property var account: null              // Account.qml
    property var apps: null                 // AppManager.qml
    property var privacy: null              // Privacy.qml
    property var updates: null              // Updates.qml
    signal setLayout(string layout)

    property string path: "system"          // z. B. "system" oder "system/sound"
    // Startseite aus etude-settings <seite> – Kurznamen wie „sound“ werden aufgelöst
    property string initialPage: ""
    Component.onCompleted: if (initialPage) path = Nav.resolve(initialPage)
    property var history: []

    // Responsiv (gekachelt oft schmal):
    //   breit   (≥ 860): Sidebar 256 px, per Button/Strg+B einklappbar
    //   mittel  (< 860): Sidebar nur Icons (48 px)
    //   schmal  (< 600): Sidebar ausgeblendet, öffnet sich als Schublade über dem Inhalt
    property bool sidebarCollapsed: false
    property bool drawerOpen: false
    readonly property bool mobile: width < 600
    readonly property bool compact: width < 860
    readonly property bool collapsed: !mobile && (sidebarCollapsed || compact)
    onMobileChanged: drawerOpen = false

    readonly property string category: path.split("/")[0]
    readonly property string sub: path.split("/")[1] || ""
    readonly property bool searching: search.text.trim() !== ""

    // Pfad für Brotkrumen und Seitentitel
    readonly property var crumbs: {
        const out = [{ label: tr.t("settings.settings"), path: "system" }]
        if (searching) return out.concat([{ label: tr.t("settings.search"), path: "" }])
        const c = Nav.category(category, tr)
        if (c) out.push({ label: c.label, path: category })
        const p = Nav.page(category, sub, tr)
        if (p) out.push({ label: p.label, path: category + "/" + sub })
        const ch = Nav.child(category, sub, path.split("/")[2] || "", tr)
        if (ch) out.push({ label: ch.label, path: path })
        return out
    }

    color: Theme.alpha(Theme.background, Theme.glassWindow)

    function toggleSidebar() {
        if (mobile) drawerOpen = !drawerOpen
        else sidebarCollapsed = !sidebarCollapsed
    }

    function navigate(p) {
        drawerOpen = false
        p = Nav.resolve(p)
        if (p === path && !searching) return
        const kb = focusInContent()
        focusHistory = focusHistory.concat([kb ? FocusNav.indexIn(focusItem, scroll) : -1])
        history = history.concat([path])
        path = p
        search.clear()
        scroll.contentY = 0
        if (kb) Qt.callLater(focusContent)
    }
    // Aufruf von außen (etude-settings <seite>, Schnelllinks der Leiste), wenn die App schon läuft:
    // Suche beenden und zur Seite wechseln
    function open(p) {
        if (searching) search.clear()
        navigate(p || "system")
    }
    function back() {
        if (searching) { search.clear(); return }
        if (history.length === 0) return
        const kb = focusInContent()
        const idx = focusHistory.length > 0 ? focusHistory[focusHistory.length - 1] : -1
        focusHistory = focusHistory.slice(0, -1)
        path = history[history.length - 1]
        history = history.slice(0, -1)
        scroll.contentY = 0
        if (kb) Qt.callLater(() => { if (!FocusNav.focusIndex(scroll, idx)) focusContent() })
    }

    // ---- Tastatur ----
    // Pfeiltasten kommen aus Etude.Ui (FocusNav), hier nur die Bereiche (arrowScope …) und:
    // Rücktaste / Alt+Links / Esc: zurück. Nach dem Öffnen per Tastatur landet der Fokus oben in der
    // neuen Seite, beim Zurück wieder auf dem Element, von dem man kam.
    readonly property Item focusItem: Window.activeFocusItem
    property var focusHistory: []            // je Verlaufsschritt: welches Element fokussiert war (zurück = wieder dort)
    function focusInContent() { return focusItem !== null && FocusNav.inside(focusItem, scroll) }
    function focusContent() { if (!FocusNav.first(scroll)) root.forceActiveFocus() }
    onFocusItemChanged: if (focusInContent()) FocusNav.reveal(focusItem)      // auch bei Tab mitscrollen

    Keys.onEscapePressed: drawerOpen ? (drawerOpen = false) : back()
    Keys.onPressed: (e) => {
        const plain = !(e.modifiers & (Qt.AltModifier | Qt.ControlModifier))
        // noch nichts fokussiert: Pfeil springt in die Seite
        if (plain && (focusItem === null || focusItem === root) &&
            (e.key === Qt.Key_Up || e.key === Qt.Key_Down || e.key === Qt.Key_Right)) FocusNav.first(scroll)
        else if (plain && (focusItem === null || focusItem === root) && e.key === Qt.Key_Left) FocusNav.first(sidebar)
        else if (plain && e.key === Qt.Key_Backspace) back()
        else if (e.key === Qt.Key_Left && (e.modifiers & Qt.AltModifier)) back()
        else if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) search.forceActiveFocus()
        else if (e.key === Qt.Key_B && (e.modifiers & Qt.ControlModifier)) toggleSidebar()
    }

    // ===================== Sidebar =====================
    Rectangle {
        id: sidebar
        property string arrowScope: "sidebar"           // Pfeiltasten (FocusNav): eigener Bereich,
        property string arrowEnter: "active"            // betreten → aktiver Eintrag,
        property string arrowRight: "content"           // Rechts → Seite
        anchors { top: parent.top; bottom: parent.bottom }
        z: 10
        width: root.collapsed ? 48 : 256                 // shadcn: 3rem / 16rem
        x: root.mobile && !root.drawerOpen ? -width - 1 : 0
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        // Schublade (schmal) immer deckend, sonst wie die Leiste durchscheinend
        color: root.mobile ? Theme.sidebar : Theme.alpha(Theme.sidebar, Theme.glass)
        clip: true

        Rectangle {                                      // border-r
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Theme.sidebarBorder
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8                           // p-2
            spacing: 8

            // ---- SidebarHeader: Benutzer ----
            SidebarMenuButton {
                Layout.fillWidth: true
                size: "lg"
                collapsed: root.collapsed
                active: !root.searching && root.category === "accounts"
                onClicked: root.navigate("accounts")
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: root.collapsed ? 0 : 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Avatar {
                        size: 32
                        radius: Theme.radiusLg
                        name: root.userName
                        source: root.avatar
                    }
                    Column {
                        visible: !root.collapsed
                        width: parent.width - 32 - 16 - 16
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: root.userName
                            elide: Text.ElideRight
                            color: Theme.sidebarForeground
                            font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: root.userDesc
                            elide: Text.ElideRight
                            color: Theme.alpha(Theme.sidebarForeground, 0.7)
                            font.family: Theme.fontSans; font.pixelSize: 12
                        }
                    }
                    Text {
                        visible: !root.collapsed
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(0xF0142)          // chevron-right
                        color: Theme.alpha(Theme.sidebarForeground, 0.7)
                        font.family: Theme.fontIcon; font.pixelSize: 16
                    }
                }
            }

            // ---- SidebarContent: Gruppen ----
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: groups.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: groups
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: Nav.groupsT(root.tr)
                        delegate: Column {
                            id: group
                            required property var modelData
                            width: groups.width
                            spacing: 4

                            SidebarGroupLabel {
                                width: parent.width
                                text: group.modelData.label
                                collapsed: root.collapsed
                            }
                            Repeater {
                                model: group.modelData.items
                                delegate: SidebarMenuButton {
                                    required property string modelData
                                    readonly property var cat: Nav.category(modelData, root.tr)
                                    width: group.width
                                    collapsed: root.collapsed
                                    icon: cat.icon
                                    text: cat.label
                                    active: !root.searching && root.category === modelData
                                    onClicked: root.navigate(modelData)
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    // ===================== Rechts: Kopfzeile + Seite =====================
    Item {
        id: main
        anchors { left: root.mobile ? parent.left : sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        // ---- Kopfzeile (shadcn: header in SidebarInset) ----
        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 56

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Theme.border
            }

            // links: Sidebar ein/aus, Zurück, Titel
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Button {
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(0xF06FD)     // page-layout-sidebar-left
                    enabled: root.mobile || !root.compact
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.toggleSidebar()
                }
                Rectangle {                                       // Separator
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 16
                    color: Theme.border
                }
                Button {
                    variant: "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(0xF004D)     // arrow-left
                    enabled: root.history.length > 0 || root.searching
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.back()
                }
                // Brotkrumen (shadcn Breadcrumb): Einstellungen / Kategorie / Seite
                Item { width: 4; height: 1 }
                Breadcrumb {
                    anchors.verticalCenter: parent.verticalCenter
                    availableWidth: search.x - 12 - parent.x - x      // bis kurz vor die Suche
                    visible: availableWidth > 40
                    items: root.crumbs
                    onNavigate: (p) => root.navigate(p)
                }
            }

            // rechts: Suche
            Input {
                id: search
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(140, Math.min(280, main.width * 0.4))
                implicitHeight: 32
                fontSize: 13
                placeholder: I18n.t("common.searchEllipsis")
                iconStart: String.fromCodePoint(0xF0349)
                onEscapePressed: root.back()
                onAccepted: {
                    const r = Nav.search(text, root.tr)
                    if (r.length > 0) root.navigate(r[0].path)
                }
            }
        }

        // ---- Seite ----
        Flickable {
            id: scroll
            property string arrowScope: "content"       // Pfeiltasten (FocusNav): eigener Bereich,
            property string arrowEnter: "first"         // betreten → oberstes Element,
            property string arrowLeft: "sidebar"        // Links → Seitenleiste
            anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
            clip: true
            contentWidth: width
            contentHeight: page.implicitHeight + 64
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: page
                // höchstens 1000 px breit, bei breiten Fenstern mittig
                readonly property real pad: root.mobile ? 16 : root.compact ? 24 : 32
                width: Math.min(scroll.width - 2 * pad, 1000)
                x: Math.max(pad, (scroll.width - width) / 2)
                y: root.mobile ? 16 : 24
                spacing: 24

                // Seitentitel: nur die aktuelle Seite (der Pfad steht oben in den Brotkrumen)
                Text {
                    text: root.crumbs[root.crumbs.length - 1].label
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: root.mobile ? 22 : 28
                    font.weight: Font.DemiBold
                }

                Loader {
                    width: page.width
                    sourceComponent: root.searching ? searchComp
                                   : root.sub !== "" ? subComp
                                   : root.category === "system" ? systemComp
                                   : root.category === "network" ? networkComp
                                   : root.category === "personalization" ? personalizationComp
                                   : root.category === "time" ? timeComp
                                   : root.category === "bluetooth" ? bluetoothComp
                                   : root.category === "accounts" ? accountsComp
                                   : root.category === "update" ? updateComp
                                   : categoryComp
                }
            }
        }
    }

    Component { id: systemComp;   SystemPage   { device: root.device; config: root.config; onNavigate: (p) => root.navigate(p) } }
    Component { id: categoryComp; CategoryPage { category: root.category; onNavigate: (p) => root.navigate(p) } }
    Component { id: searchComp;   SearchPage   { query: search.text; onNavigate: (p) => root.navigate(p) } }

    // Unterseiten: fertige Seiten hier eintragen, der Rest zeigt "in Arbeit"
    Component {
        id: subComp
        Loader {
            sourceComponent: root.path === "system/multitasking" ? multitaskingComp
                           : root.path === "system/sound" ? soundComp
                           : root.path === "network/wifi" ? wifiComp
                           : root.path === "network/ethernet" ? ethernetComp
                           : root.path === "network/vpn" ? vpnComp
                           : root.path === "network/advanced" ? advancedComp
                           : root.path === "network/wifi/known" ? knownComp
                           : root.path === "system/sound/mixer" ? mixerComp
                           : root.path === "personalization/background" ? backgroundComp
                           : root.path === "personalization/colors" ? colorsComp
                           : root.path === "personalization/lockscreen" ? lockScreenComp
                           : root.path === "personalization/taskbar" ? taskbarComp
                           : root.path === "system/about" ? aboutComp
                           : root.path === "system/storage" ? storageComp
                           : root.path === "system/power" ? powerComp
                           : root.path === "system/display" ? displayComp
                           : root.path === "system/notifications" ? notificationsComp
                           : root.path === "apps/installed" ? installedAppsComp
                           : root.path === "privacy/firewall" ? firewallComp
                           : root.path === "privacy/microphone" ? microphoneComp
                           : root.path === "privacy/camera" ? cameraComp
                           : root.path === "privacy/location" ? locationComp
                           : root.path === "apps/defaults" ? defaultAppsComp
                           : root.path === "apps/startup" ? startupAppsComp
                           : root.path === "accounts/info" ? accountInfoComp
                           : root.path === "accounts/signin" ? signInComp
                           : root.path === "accounts/users" ? usersComp
                           : root.path === "bluetooth/devices" ? devicesComp
                           : root.path === "bluetooth/mouse" ? mouseComp
                           : root.path === "bluetooth/touchpad" ? touchpadComp
                           : root.path === "network/proxy" ? proxyComp
                           : root.path === "time/datetime" ? dateTimeComp
                           : root.path === "time/language" ? languageComp
                           : root.path === "time/keyboard" ? keyboardComp
                           : comingSoonComp
        }
    }
    Component { id: comingSoonComp; ComingSoon { } }
    Component { id: soundComp;      SoundPage   { audio: root.audio; onNavigate: (p) => root.navigate(p) } }
    Component { id: networkComp;    NetworkPage  { network: root.network; onNavigate: (p) => root.navigate(p) } }
    Component { id: wifiComp;       WifiPage     { network: root.network; onNavigate: (p) => root.navigate(p) } }
    Component { id: ethernetComp;   EthernetPage { network: root.network } }
    Component { id: vpnComp;        VpnPage      { network: root.network } }
    Component { id: advancedComp;   NetworkAdvancedPage { network: root.network } }
    Component { id: knownComp;      KnownNetworksPage { network: root.network } }
    Component { id: mixerComp;      MixerPage    { audio: root.audio } }
    Component { id: personalizationComp; PersonalizationPage { config: root.config; onNavigate: (p) => root.navigate(p) } }
    Component { id: backgroundComp; BackgroundPage { config: root.config } }
    Component { id: colorsComp;     ColorsPage     { config: root.config } }
    Component { id: lockScreenComp; LockScreenPage { config: root.config } }
    Component { id: taskbarComp;    TaskbarPage    { config: root.config; apps: root.apps; battery: root.battery; bluetooth: root.bluetooth } }
    Component { id: aboutComp;      AboutPage      { device: root.device; updates: root.updates } }
    Component { id: updateComp;     UpdatePage     { updates: root.updates } }
    Component { id: storageComp;    StoragePage    { storage: root.storage } }
    Component { id: bluetoothComp;  BluetoothPage  { bluetooth: root.bluetooth; hypr: root.hypr; onNavigate: (p) => root.navigate(p) } }
    Component { id: devicesComp;    DevicesPage    { bluetooth: root.bluetooth } }
    Component { id: mouseComp;      MousePage      { hypr: root.hypr } }
    Component { id: touchpadComp;   TouchpadPage   { hypr: root.hypr } }
    Component { id: accountsComp;    AccountsPage    { account: root.account; onNavigate: (p) => root.navigate(p) } }
    Component { id: accountInfoComp; AccountInfoPage { account: root.account } }
    Component { id: signInComp;      SignInPage      { account: root.account; onNavigate: (p) => root.navigate(p) } }
    Component { id: usersComp;       UsersPage       { account: root.account } }
    Component { id: displayComp;    DisplayPage    { displays: root.displays; brightness: root.brightness; config: root.config } }
    Component { id: firewallComp;   FirewallPage   { privacy: root.privacy } }
    Component { id: microphoneComp; MicrophonePage { audio: root.audio; onNavigate: (p) => root.navigate(p) } }
    Component { id: cameraComp;     CameraPage     { privacy: root.privacy; audio: root.audio } }
    Component { id: locationComp;   LocationPage   { privacy: root.privacy } }
    Component { id: installedAppsComp; InstalledAppsPage { apps: root.apps } }
    Component { id: defaultAppsComp;   DefaultAppsPage   { apps: root.apps } }
    Component { id: startupAppsComp;   StartupAppsPage   { apps: root.apps } }
    Component { id: notificationsComp; NotificationsPage { config: root.config } }
    Component { id: powerComp;      PowerPage      { config: root.config; battery: root.battery; power: root.power } }
    Component { id: proxyComp;      ProxyPage      { hypr: root.hypr } }
    Component { id: timeComp;       TimeLanguagePage { timedate: root.timedate; config: root.config; onNavigate: (p) => root.navigate(p) } }
    Component { id: dateTimeComp;   DateTimePage   { timedate: root.timedate; config: root.config } }
    Component { id: languageComp;   LanguagePage   { timedate: root.timedate } }
    Component { id: keyboardComp;   KeyboardPage   { hypr: root.hypr } }
    Component {
        id: multitaskingComp
        MultitaskingPage {
            layout: root.hyprLayout
            onSetLayout: (l) => root.setLayout(l)
        }
    }

    // Schublade (schmal): Klick daneben schließt
    Rectangle {
        anchors.fill: parent
        z: 9
        color: "#000000"
        opacity: root.mobile && root.drawerOpen ? 0.5 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.drawerOpen = false }
    }
}
