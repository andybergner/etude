import QtQuick
import QtQuick.Layouts
import Quickshell
import Etude.Ui
import "pages"

// Task-Manager – Kopfzeile über die volle Breite (Sidebar-Button, Brotkrumen, Suche rechts),
// darunter shadcn-Sidebar (Seiten, einklappbar) und die Seite.
// Seiten: Prozesse, Leistung, Autostart von Apps, Details, Dienste.
Rectangle {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    property var sys: null                 // System.qml
    property var services: null            // Services.qml
    property var apps: null                // Etude.Services/AppManager

    property string page: "processes"
    // wie die Einstellungen: breit 256 px (Strg+B), unter 860 px nur Icons
    property bool sidebarCollapsed: false
    readonly property bool compact: width < 860
    readonly property bool collapsed: sidebarCollapsed || compact
    property int detailsPid: -1

    readonly property var pages: [
        { id: "processes",   label: tr.t("tm.processes"),           icon: 0xF0BEB },
        { id: "performance", label: tr.t("tm.performance"),           icon: 0xF012A },
        { id: "startup",     label: tr.t("tm.startupApps"), icon: 0xF040A },
        { id: "details",     label: tr.t("tm.details"),            icon: 0xF0279 },
        { id: "services",    label: tr.t("tm.services"),            icon: 0xF0493 }
    ]

    color: Theme.alpha(Theme.background, Theme.glassWindow)

    onPageChanged: if (page !== "details") detailsPid = -1
    function open(p) { if (pages.some(x => x.id === p)) page = p }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) searchInput.forceActiveFocus()
        else if (e.key === Qt.Key_B && (e.modifiers & Qt.ControlModifier)) sidebarCollapsed = !sidebarCollapsed
        else if (e.key === Qt.Key_Delete && pageLoader.item && pageLoader.item.endTask) pageLoader.item.endTask()
    }

    // ===================== Kopfzeile (volle Breite) =====================
    Item {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 56
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }

        // links: Sidebar ein/aus, Brotkrumen
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Button {
                variant: "ghost"
                size: "icon-sm"
                iconStart: String.fromCodePoint(0xF06FD)
                enabled: !root.compact
                opacity: enabled ? 1 : 0.4
                onClicked: root.sidebarCollapsed = !root.sidebarCollapsed
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: Theme.border }
            Item { width: 8; height: 1 }
            Breadcrumb {
                anchors.verticalCenter: parent.verticalCenter
                availableWidth: searchInput.x - 12 - parent.x - x
                visible: availableWidth > 40
                items: [{ label: tr.t("tm.taskManager"), path: "processes" },
                        { label: (root.pages.find(x => x.id === root.page) || {}).label || "", path: root.page }]
                onNavigate: (p) => root.page = p
            }
        }

        // rechts: Suche
        Input {
            id: searchInput
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(160, Math.min(320, root.width * 0.4))
            implicitHeight: 32
            fontSize: 13
            placeholder: tr.t("tm.searchNameOrPid")
            iconStart: String.fromCodePoint(0xF0349)
            onEscapePressed: text = ""
        }
    }

    // ===================== Seitenleiste (shadcn Sidebar) =====================
    Rectangle {
        id: sidebar
        property string arrowScope: "sidebar"           // Pfeiltasten: Hoch/Runter bleibt in der Leiste
        property string arrowEnter: "active"            // Links aus dem Inhalt → aktiver Eintrag
        anchors { left: parent.left; top: topBar.bottom; bottom: parent.bottom }
        width: root.collapsed ? 48 : 256
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        color: Theme.alpha(Theme.sidebar, Theme.glass)
        clip: true
        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.sidebarBorder }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // ---- SidebarContent ----
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                SidebarGroupLabel { width: parent.width; text: tr.t("tm.overview"); collapsed: root.collapsed }
                Repeater {
                    model: root.pages
                    SidebarMenuButton {
                        required property var modelData
                        width: parent.width
                        collapsed: root.collapsed
                        icon: String.fromCodePoint(modelData.icon)
                        text: modelData.label
                        active: root.page === modelData.id
                        onClicked: root.page = modelData.id
                    }
                }
            }
        }
    }

    // ===================== Rechts: Kopfzeile + Seite =====================
    Item {
        id: main
        anchors { left: sidebar.right; right: parent.right; top: topBar.bottom; bottom: parent.bottom }

        Loader {
            id: pageLoader
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
            sourceComponent: root.page === "processes" ? processesComp
                           : root.page === "performance" ? performanceComp
                           : root.page === "startup" ? startupComp
                           : root.page === "details" ? detailsComp
                           : servicesComp
        }
    }

    Component {
        id: processesComp
        ProcessesPage {
            sys: root.sys
            search: searchInput.text
            onRunTaskRequested: root.openRunDialog()
            onContextMenuRequested: (entries, x, y) => root.showMenu(entries, mapToItem(root, x, y))
            onShowDetails: (pid) => { root.detailsPid = pid; root.page = "details" }
        }
    }
    Component { id: performanceComp; PerformancePage { sys: root.sys; onRunTaskRequested: root.openRunDialog() } }
    Component { id: startupComp; StartupPage { apps: root.apps; search: searchInput.text } }
    Component {
        id: detailsComp
        DetailsPage {
            sys: root.sys
            search: searchInput.text
            focusPid: root.detailsPid
            onRunTaskRequested: root.openRunDialog()
            onContextMenuRequested: (entries, x, y) => root.showMenu(entries, mapToItem(root, x, y))
        }
    }
    Component {
        id: servicesComp
        ServicesPage {
            services: root.services
            search: searchInput.text
            onContextMenuRequested: (entries, x, y) => root.showMenu(entries, mapToItem(root, x, y))
        }
    }

    // ===================== Kontextmenü =====================
    function showMenu(entries, pos) {
        menu.model = entries
        menu.currentIndex = -1
        menu.x = Math.min(pos.x, root.width - menu.menuWidth - 8)
        menu.y = Math.min(pos.y, root.height - menu.implicitHeight - 8)
        menuLayer.visible = true
        menu.forceActiveFocus()
    }
    Item {
        id: menuLayer
        anchors.fill: parent
        visible: false
        z: 50
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: menuLayer.visible = false }
        ContextMenu {
            id: menu
            menuWidth: 240
            onTriggered: (entry) => {
                menuLayer.visible = false
                if (pageLoader.item && pageLoader.item.menuAction) pageLoader.item.menuAction(entry.action)
            }
            onCloseRequested: menuLayer.visible = false
            MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
        }
    }

    // ===================== Neuen Task ausführen =====================
    function openRunDialog() {
        runInput.text = ""
        runAdmin.checked = false
        runDialog.open()
        runInput.forceActiveFocus()
    }
    Dialog {
        id: runDialog
        title: tr.t("tm.runNewTask")
        description: tr.t("tm.enterTheNameOfA")
        Field {
            width: parent.width
            label: tr.t("tm.open")
            Input { id: runInput; width: parent.width; placeholder: tr.t("tm.eGFirefox"); onAccepted: runBtn.clicked() }
        }
        Item {
            width: parent.width
            height: runAdmin.height
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: tr.t("tm.runWithAdministratorRights")
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 14
            }
            Switch {
                id: runAdmin
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
                id: runBtn
                text: "OK"
                enabled: runInput.text.trim() !== ""
                onClicked: { root.sys.runTask(runInput.text, runAdmin.checked); runDialog.close() }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: runDialog.close() }
        }
    }

    // Fehler beim Beenden
    Rectangle {
        id: toast
        property string text: ""
        visible: opacity > 0
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        anchors.horizontalCenter: main.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: toastText.implicitWidth + 32
        height: 40
        radius: Theme.radiusLg
        color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
        border.width: 1
        border.color: Theme.alpha(Theme.destructive, 0.5)
        z: 60
        Text { id: toastText; anchors.centerIn: parent; text: toast.text; color: Theme.destructive; font.family: Theme.fontSans; font.pixelSize: 13 }
        Timer { id: toastTimer; interval: 4000; onTriggered: toast.opacity = 0 }
    }
    Connections {
        target: root.sys
        function onKillFailed(msg) { toast.text = msg || tr.t("tm.theProcessCouldNotBe"); toast.opacity = 1; toastTimer.restart() }
    }
}
