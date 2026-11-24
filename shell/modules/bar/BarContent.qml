import QtQuick
import QtQuick.Layouts
import Quickshell
import Etude.Ui
import "Icons.js" as Icons

// Leiste im Windows-11-Stil mit frei wählbarem Aufbau (Einstellungen › Personalisierung › Taskleiste):
// Bereiche links, Mitte, rechts; Elemente Start, Desktops, Apps, Infobereich, Benachrichtigungen, Uhr.
Item {
    id: root
    property Translations tr: Translations { domain: "bar" }   // Texte dieses Moduls

    // ---------- Farben aus dem Theme (shadcn sidebar-*) ----------
    // Die Leiste ist wie eine Sidebar: eigene Fläche, abgesetzt vom Hintergrund.
    readonly property color bg:   Theme.alpha(Theme.sidebar, Theme.glass)
    readonly property color line: Theme.sidebarBorder
    readonly property color fg:   Theme.sidebarForeground
    readonly property color dim:  Theme.mutedForeground

    property bool atBottom: true          // Linie an der Innenkante

    // ---------- Daten ----------
    property int activeWorkspace: 1
    property int workspaceCount: 5
    property var barLayout: ({ left: ["start", "workspaces"], center: [], right: ["network", "bluetooth", "sound", "battery", "notifications", "clock"], hidden: ["apps"] })
    property var pinnedApps: []            // angeheftete Apps (Desktop-IDs)
    property string netKind: "wifi"        // "wifi" | "ethernet" | "none"
    property int netSignal: 80
    property bool wifiEnabled: true
    property real volume: 0.5
    property bool muted: false
    property bool btPresent: false
    property bool btEnabled: false
    property bool btConnected: false
    property bool hasBattery: false
    property int batteryLevel: 100
    property bool charging: false
    property date now: new Date()
    property bool clock24: true
    property bool clockSeconds: false
    property var micApps: []               // Apps, die gerade das Mikrofon benutzen
    property int notifCount: 0             // Benachrichtigungen im Center
    property bool dnd: false               // Nicht stören

    // ---------- Aktionen ----------
    signal startClicked()
    signal startRightClicked()             // Kontextmenü (wie Win + X)

    property alias startButton: startBtn   // zum Verankern von Menüs
    property alias clockButton: clockBtn
    property alias bellButton: bellBtn
    property alias micButton: micBtn
    property alias appsItem: appsGroup
    // Button unter der Maus (für den Tooltip in Bar.qml)
    readonly property Item hoveredButton: [startBtn, micBtn, netBtn, btBtn, volBtn, batBtn, bellBtn, clockBtn]
        .find(b => b.visible && b.hovered && b.parent !== store) || appsGroup.hoveredItem
    property alias networkButton: netBtn
    property alias bluetoothButton: btBtn
    property alias volumeButton: volBtn
    property alias batteryButton: batBtn
    signal workspaceClicked(int id)
    signal networkClicked()
    signal bluetoothClicked()
    signal volumeClicked()
    signal batteryClicked()
    signal volumeScrolled(int direction)
    signal clockClicked()                  // öffnet den Kalender
    signal notificationsClicked()          // öffnet das Benachrichtigungscenter
    signal micClicked()                    // öffnet Datenschutz › Mikrofon
    signal appMenuRequested(var app, Item button)   // Rechtsklick auf eine App

    // nur für Vorschauen
    property bool previewHoverStatus: false

    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        color: root.bg
        Rectangle {                         // feine Linie zur Bildschirmmitte hin (wie Windows 11)
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.atBottom ? 0 : parent.height - 1
            height: 1
            color: root.line
        }
    }

    // ===== Aufbau: drei Bereiche, Inhalt und Reihenfolge aus barLayout =====
    // Die Elemente gibt es je einmal (unten im Lager); applyLayout() hängt sie in die Bereiche.
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
    }
    Row {
        id: centerRow
        anchors.centerIn: parent
        spacing: 4
    }
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
    }

    readonly property var widgets: ({ start: startBtn, workspaces: wsGroup, apps: appsGroup,
                                      network: netBtn, bluetooth: btBtn, sound: soundGroup, battery: batBtn,
                                      notifications: bellBtn, clock: clockBtn })
    // alter Aufbau: "tray" stand für Netzwerk, Bluetooth, Sound und Akku zusammen
    function expand(ids) { return ids.reduce((a, id) => a.concat(id === "tray" ? ["network", "bluetooth", "sound", "battery"] : [id]), []) }
    function applyLayout() {
        const l = root.barLayout || {}
        const zones = [[leftRow, expand(l.left || [])], [centerRow, expand(l.center || [])], [rightRow, expand(l.right || [])]]
        for (const k in widgets) widgets[k].parent = store            // erst alles ins Lager …
        for (const [row, ids] of zones)                               // … dann in Reihenfolge einhängen
            for (const id of ids) if (widgets[id]) widgets[id].parent = row
    }
    onBarLayoutChanged: applyLayout()
    Component.onCompleted: applyLayout()

    // ===== Lager: alle Elemente (unsichtbar, solange sie keinem Bereich zugeordnet sind) =====
    Item {
        id: store
        visible: false

    BarItem {
        id: startBtn
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        padX: 0
        implicitWidth: 32
        onClicked: root.startClicked()
        onRightClicked: root.startRightClicked()
        EtudeLogo {
            size: 18
            monoColor: root.fg      // einfarbig als Icon
        }
    }

    Row {
        id: wsGroup
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        spacing: 0
        Repeater {
            model: root.workspaceCount
            delegate: BarItem {
                id: ws
                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: wsId === root.activeWorkspace
                        padX: 0
                implicitWidth: 30
                onClicked: root.workspaceClicked(wsId)

                Item {
                    width: 12; height: 18
                    Text {
                        anchors.centerIn: parent
                        visible: !ws.active
                        text: ws.wsId
                        color: root.dim
                        font.family: Theme.fontSans
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: ws.active
                        width: 8; height: 8; radius: 4
                        color: root.fg
                    }
                }
            }
        }
    }

        // Apps: angeheftet und laufend
        TaskApps {
            id: appsGroup
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            pinned: root.pinnedApps
            fg: root.fg
            dim: root.dim
            onMenuRequested: (app, button) => root.appMenuRequested(app, button)
        }

        // Netzwerk, Bluetooth, Sound (Mikrofon-Anzeige + Lautsprecher), Akku – einzeln verschiebbar
        BarItem {
            id: netBtn
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            padX: 0; implicitWidth: 32
            forceHover: root.previewHoverStatus
            onClicked: root.networkClicked()
            Text {
                text: root.netKind === "ethernet" ? Icons.ethernet
                    : root.netKind === "wifi" ? (root.netSignal > 75 ? Icons.wifi4 : root.netSignal > 50 ? Icons.wifi3 : root.netSignal > 25 ? Icons.wifi2 : Icons.wifi1)
                    : root.wifiEnabled ? Icons.netOff : Icons.wifiOff
                color: root.netKind === "none" ? root.dim : root.fg
                font.family: Theme.fontIcon; font.pixelSize: 16
            }
        }

        BarItem {
            id: btBtn
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            visible: root.btPresent
            padX: 0; implicitWidth: 32
            onClicked: root.bluetoothClicked()
            Text {
                text: !root.btEnabled ? Icons.btOff : root.btConnected ? Icons.btConnected : Icons.bluetooth
                color: root.btEnabled ? root.fg : root.dim
                font.family: Theme.fontIcon; font.pixelSize: 16
            }
        }

        Row {
            id: soundGroup
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            spacing: 0
            BarItem {
                id: micBtn
                visible: root.micApps.length > 0
                padX: 0; implicitWidth: 32
                onClicked: root.micClicked()
                Text {
                    text: String.fromCodePoint(0xF036C)
                    color: Theme.primary
                    font.family: Theme.fontIcon; font.pixelSize: 16
                }
            }
            BarItem {
                id: volBtn
                padX: 0; implicitWidth: 32
                onClicked: root.volumeClicked()
                onScrolled: (d) => root.volumeScrolled(d)
                Text {
                    text: root.muted || root.volume === 0 ? Icons.volMute
                        : root.volume > 0.66 ? Icons.volHigh
                        : root.volume > 0.33 ? Icons.volMedium : Icons.volLow
                    color: root.muted ? root.dim : root.fg
                    font.family: Theme.fontIcon; font.pixelSize: 16
                }
            }
        }

        BarItem {
            id: batBtn
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            visible: root.hasBattery
            padX: 0; implicitWidth: 32
            onClicked: root.batteryClicked()
            Text {
                text: root.charging ? Icons.batteryCharging : Icons.battery(root.batteryLevel)
                color: root.batteryLevel <= 15 && !root.charging ? Theme.destructive : root.fg
                font.family: Theme.fontIcon; font.pixelSize: 16
            }
        }

    BarItem {
        id: bellBtn
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        padX: 0
        implicitWidth: 32
        onClicked: root.notificationsClicked()
        Text {
            text: String.fromCodePoint(root.dnd ? 0xF009B : 0xF009C)
            color: root.dnd ? root.dim : root.fg
            font.family: Theme.fontIcon; font.pixelSize: 16
        }
        // Anzahl der Benachrichtigungen unten rechts an der Glocke
        overlay: Rectangle {
            id: badge
            visible: root.notifCount > 0 && !root.dnd
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 1
            anchors.rightMargin: 1
            width: Math.max(14, countText.implicitWidth + 6)
            height: 14
            radius: 7
            z: 10
            color: Theme.primary
            Text {
                id: countText
                anchors.centerIn: parent
                text: root.notifCount > 99 ? "99+" : root.notifCount
                color: Theme.primaryForeground
                font.family: Theme.fontSans; font.pixelSize: 9; font.weight: Font.DemiBold
            }
        }
    }

    BarItem {
        id: clockBtn
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        padX: 8
        onClicked: root.clockClicked()
        // passt sich dem Bereich an: links linksbündig, rechts rechtsbündig, Mitte nebeneinander
        readonly property string place: parent === leftRow ? "left" : parent === centerRow ? "center" : "right"
        Grid {
            columns: clockBtn.place === "center" ? 2 : 1
            columnSpacing: 8
            horizontalItemAlignment: clockBtn.place === "left" ? Grid.AlignLeft : Grid.AlignRight
            verticalItemAlignment: Grid.AlignVCenter
            Text {
                text: root.now.toLocaleTimeString(I18n.locale,
                      (root.clock24 ? "HH:mm" : "h:mm") + (root.clockSeconds ? ":ss" : "") + (root.clock24 ? "" : " AP"))
                color: root.fg
                font.family: Theme.fontSans
                font.pixelSize: clockBtn.place === "center" ? 12 : 11
                font.weight: Font.Medium
            }
            Text {
                text: root.now.toLocaleDateString(I18n.locale, root.tr.t("bar.dateFormat"))
                color: root.fg
                opacity: clockBtn.place === "center" ? 0.75 : 1
                font.family: Theme.fontSans
                font.pixelSize: clockBtn.place === "center" ? 12 : 11
            }
        }
    }
    }
}
