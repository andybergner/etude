import QtQuick
import Etude.Ui
import "../components"
import "../components/Model.js" as Model

// Details (wie Windows 11): alle Prozesse flach mit PID, Status, Benutzer, CPU, Arbeitsspeicher, Threads.
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    required property var sys              // System.qml
    property string search: ""
    property int focusPid: -1              // von "Zu Details wechseln"
    signal runTaskRequested()
    signal contextMenuRequested(var entries, real x, real y)

    property string sortKey: "cpu"
    property bool sortDesc: true
    property int selectedPid: -1

    readonly property var columns: [
        { key: "name",    label: tr.t("tm.name"),            width: 0,   align: "left" },
        { key: "pid",     label: "PID",             width: 80,  align: "right" },
        { key: "state",   label: tr.t("tm.status"),          width: 130, align: "left" },
        { key: "user",    label: tr.t("tm.userName"),        width: 120, align: "left" },
        { key: "cpu",     label: "CPU",             width: 80,  align: "right" },
        { key: "mem",     label: tr.t("tm.memory"), width: 130, align: "right" },
        { key: "threads", label: tr.t("tm.threads"),         width: 80,  align: "right" }
    ]

    function stateLabel(s) {
        return s === "R" ? tr.t("tm.running") : s === "S" ? tr.t("tm.sleeping") : s === "D" ? tr.t("tm.waitingIO")
             : s === "T" || s === "t" ? tr.t("tm.stopped") : s === "Z" ? tr.t("tm.zombie") : s === "I" ? tr.t("tm.idle") : s
    }

    ListModel { id: rowModel }

    function rebuild() {
        const q = search.trim().toLowerCase()
        let list = sys.processes.filter(p => !q || p.name.toLowerCase().indexOf(q) >= 0
                                             || String(p.pid).indexOf(q) === 0 || p.user.toLowerCase().indexOf(q) >= 0)
        const k = sortKey
        list = list.slice().sort((a, b) => {
            let r = (typeof a[k] === "string") ? a[k].localeCompare(b[k]) : a[k] - b[k]
            return sortDesc ? -r : r
        })
        Model.sync(rowModel, list.map(p => ({ pid: p.pid, name: p.name, state: stateLabel(p.state), user: p.user,
                                               cpu: p.cpu, mem: p.mem, threads: p.threads })))
        if (focusPid > 0) {
            const i = list.findIndex(p => p.pid === focusPid)
            if (i >= 0) { selectedPid = focusPid; list_.positionViewAtIndex(i, ListView.Center) }
            focusPid = -1
        }
    }
    Connections { target: root.sys; function onProcessesChanged() { root.rebuild() } }
    onSearchChanged: rebuild()
    onSortKeyChanged: rebuild()
    onSortDescChanged: rebuild()
    onFocusPidChanged: if (focusPid > 0) rebuild()

    PageHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: tr.t("tm.details")
        Button {
            variant: "ghost"; size: "sm"
            iconStart: String.fromCodePoint(0xF0415)
            text: tr.t("tm.runNewTask")
            onClicked: root.runTaskRequested()
        }
        Button {
            variant: "outline"; size: "sm"
            iconStart: String.fromCodePoint(0xF0156)
            text: tr.t("tm.endTask")
            enabled: root.selectedPid > 0
            onClicked: root.sys.kill([root.selectedPid], false)
        }
    }

    TableHeader {
        id: tableHead
        anchors { left: parent.left; right: parent.right; top: head.bottom; rightMargin: 12 }
        columns: root.columns
        sortKey: root.sortKey
        sortDesc: root.sortDesc
        onSortRequested: (k) => { if (root.sortKey === k) root.sortDesc = !root.sortDesc; else { root.sortKey = k; root.sortDesc = ["cpu", "mem", "threads"].indexOf(k) >= 0 } }
    }

    ListView {
        id: list_
        anchors { left: parent.left; right: parent.right; top: tableHead.bottom; bottom: parent.bottom }
        clip: true
        model: rowModel
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        activeFocusOnTab: true                       // per Tab/Pfeil erreichbar, Pfeile wählen darin
        keyNavigationEnabled: false                  // Pfeile macht Keys.onPressed (am Rand weiter zum Nachbarn)
        function currentRow() {
            for (let i = 0; i < rowModel.count; i++) if (rowModel.get(i).pid === root.selectedPid) return i
            return -1
        }
        function selectRow(i) { root.selectedPid = rowModel.get(i).pid; positionViewAtIndex(i, ListView.Contain) }
        onActiveFocusChanged: if (activeFocus && root.selectedPid <= 0 && rowModel.count > 0) selectRow(0)
        Keys.onPressed: (e) => {
            const i = FocusNav.listKey(e, rowModel.count, currentRow())
            if (i >= 0) { selectRow(i); e.accepted = true }
        }

        delegate: Item {
            id: rowItem
            required property int pid
            required property string name
            required property string state
            required property string user
            required property real cpu
            required property real mem
            required property int threads

            width: list_.width - 12
            height: 32
            readonly property bool selected: root.selectedPid === pid

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
                    root.selectedPid = rowItem.pid
                    list_.forceActiveFocus()                 // danach mit Pfeilen weiter
                    if (e.button === Qt.RightButton) {
                        const p = mapToItem(root, e.x, e.y)
                        root.contextMenuRequested([
                            { label: tr.t("tm.endTask"), icon: String.fromCodePoint(0xF0156), action: "end" },
                            { label: tr.t("tm.endImmediatelyForce"), icon: String.fromCodePoint(0xF0028), action: "kill", variant: "destructive" },
                            { type: "separator" },
                            { label: tr.t("tm.openFileLocation"), icon: String.fromCodePoint(0xF0770), action: "location" }
                        ], p.x, p.y)
                    }
                }
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: [
                        { w: 0, t: rowItem.name, r: false },
                        { w: 80, t: String(rowItem.pid), r: true },
                        { w: 130, t: rowItem.state, r: false },
                        { w: 120, t: rowItem.user, r: false },
                        { w: 80, t: Math.round(rowItem.cpu * 100) + " %", r: true },
                        { w: 130, t: root.sys.bytes(rowItem.mem), r: true },
                        { w: 80, t: String(rowItem.threads), r: true }
                    ]
                    Item {
                        required property var modelData
                        width: modelData.w || Math.max(80, rowItem.width - 620)
                        height: rowItem.height
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: modelData.r ? Text.AlignRight : Text.AlignLeft
                            elide: Text.ElideRight
                            text: modelData.t
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }

    function menuAction(a) {
        if (selectedPid <= 0) return
        if (a === "end") sys.kill([selectedPid], false)
        else if (a === "kill") sys.kill([selectedPid], true)
        else if (a === "location") sys.openLocation(selectedPid)
    }

    Component.onCompleted: rebuild()
}
