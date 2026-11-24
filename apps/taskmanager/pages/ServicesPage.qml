import QtQuick
import Etude.Ui
import "../components"
import "../components/Model.js" as Model

// Dienste (wie Windows 11): systemd-Dienste mit Beschreibung, Status, Starttyp.
// Systemdienste ändern → Benutzerkontensteuerung; Benutzerdienste direkt.
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    required property var services         // Services.qml
    property string search: ""
    signal contextMenuRequested(var entries, real x, real y)

    property string sortKey: "name"
    property bool sortDesc: false
    property string selected: ""
    readonly property var selectedService: services.services.find(s => s.unit === selected) || null

    Component.onCompleted: services.refresh()

    readonly property var columns: [
        { key: "name",        label: tr.t("tm.name"),         width: 240, align: "left" },
        { key: "description", label: tr.t("tm.description"), width: 0,   align: "left" },
        { key: "state",       label: tr.t("tm.status"),       width: 150, align: "left" },
        { key: "startup",     label: tr.t("tm.startupType"),     width: 130, align: "left" }
    ]
    function stateLabel(s) { return s === "running" ? tr.t("tm.running") : s === "failed" ? tr.t("tm.failed") : tr.t("tm.stopped2") }

    ListModel { id: rowModel }
    function rebuild() {
        const q = search.trim().toLowerCase()
        const k = sortKey
        const list = services.services
            .filter(s => !q || s.name.toLowerCase().indexOf(q) >= 0 || s.description.toLowerCase().indexOf(q) >= 0)
            .slice().sort((a, b) => { const r = String(a[k]).localeCompare(String(b[k])); return sortDesc ? -r : r })
        Model.sync(rowModel, list.map(s => ({ unit: s.unit, name: s.name, description: s.description,
                                               state: s.state, startup: s.startup })))
    }
    Connections { target: root.services; function onServicesChanged() { root.rebuild() } }
    onSearchChanged: rebuild()
    onSortKeyChanged: rebuild()
    onSortDescChanged: rebuild()

    PageHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: tr.t("tm.services")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "system", label: tr.t("tm.system") }, { value: "user", label: tr.t("tm.userName") }]
            value: root.services.user ? "user" : "system"
            onSelected: (v) => { root.selected = ""; root.services.user = v === "user" }
        }
        Item { width: 8; height: 1 }
        Button {
            variant: "ghost"; size: "sm"
            iconStart: String.fromCodePoint(0xF040A)
            text: tr.t("tm.start")
            enabled: !!root.selectedService && root.selectedService.state !== "running"
            onClicked: root.services.control(root.selectedService, "start")
        }
        Button {
            variant: "ghost"; size: "sm"
            iconStart: String.fromCodePoint(0xF04DB)
            text: tr.t("tm.stop")
            enabled: !!root.selectedService && root.selectedService.state === "running"
            onClicked: root.services.control(root.selectedService, "stop")
        }
        Button {
            variant: "ghost"; size: "sm"
            iconStart: String.fromCodePoint(0xF0453)
            text: tr.t("tm.restart")
            enabled: !!root.selectedService
            onClicked: root.services.control(root.selectedService, "restart")
        }
    }

    Text {
        id: err
        visible: root.services.error !== ""
        anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 24; rightMargin: 24 }
        bottomPadding: 6
        wrapMode: Text.Wrap
        text: root.services.error
        color: Theme.destructive
        font.family: Theme.fontSans; font.pixelSize: 12
    }

    TableHeader {
        id: tableHead
        anchors { left: parent.left; right: parent.right; top: err.visible ? err.bottom : head.bottom; rightMargin: 12 }
        columns: root.columns
        sortKey: root.sortKey
        sortDesc: root.sortDesc
        onSortRequested: (k) => { if (root.sortKey === k) root.sortDesc = !root.sortDesc; else { root.sortKey = k; root.sortDesc = false } }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: tableHead.bottom; bottom: parent.bottom }
        clip: true
        model: rowModel
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        activeFocusOnTab: true                       // per Tab/Pfeil erreichbar, Pfeile wählen darin
        keyNavigationEnabled: false                  // Pfeile macht Keys.onPressed (am Rand weiter zum Nachbarn)
        function currentRow() {
            for (let i = 0; i < rowModel.count; i++) if (rowModel.get(i).unit === root.selected) return i
            return -1
        }
        function selectRow(i) { root.selected = rowModel.get(i).unit; positionViewAtIndex(i, ListView.Contain) }
        onActiveFocusChanged: if (activeFocus && !root.selected && rowModel.count > 0) selectRow(0)
        Keys.onPressed: (e) => {
            const i = FocusNav.listKey(e, rowModel.count, currentRow())
            if (i >= 0) { selectRow(i); e.accepted = true }
        }

        delegate: Item {
            id: rowItem
            required property string unit
            required property string name
            required property string description
            required property string state
            required property string startup
            width: list.width - 12
            height: 32
            readonly property bool selected: root.selected === unit

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                radius: Theme.radiusMd
                color: rowItem.selected ? Theme.alpha(Theme.primary, 0.14) : "transparent"
                HoverLayer { shown: mouse.containsMouse; level: 0.6 }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (e) => {
                    root.selected = rowItem.unit
                    list.forceActiveFocus()                  // danach mit Pfeilen weiter
                    if (e.button === Qt.RightButton) {
                        const p = mapToItem(root, e.x, e.y)
                        root.contextMenuRequested([
                            { label: tr.t("tm.start"), action: "start", disabled: rowItem.state === "running" },
                            { label: tr.t("tm.stop"), action: "stop", disabled: rowItem.state !== "running" },
                            { label: tr.t("tm.restart"), action: "restart" }
                        ], p.x, p.y)
                    }
                }
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: [
                        { w: 240, t: rowItem.name },
                        { w: 0, t: rowItem.description },
                        { w: 150, t: root.stateLabel(rowItem.state), c: rowItem.state === "failed" ? Theme.destructive : rowItem.state === "running" ? Theme.foreground : Theme.mutedForeground },
                        { w: 130, t: rowItem.startup }
                    ]
                    Item {
                        required property var modelData
                        width: modelData.w || Math.max(80, rowItem.width - 520)
                        height: rowItem.height
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: modelData.t
                            color: modelData.c || Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    function menuAction(a) { if (selectedService) services.control(selectedService, a) }
}
