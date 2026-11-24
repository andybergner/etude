import QtQuick
import Quickshell
import Quickshell.Hyprland
import Etude.Ui
import "../components"
import "../components/Model.js" as Model

// Prozesse (wie Windows 11): Apps (mit Fenster, aufklappbar), Hintergrundprozesse, Systemprozesse.
// Spalten: Name, CPU, Arbeitsspeicher, Datenträger – Werte farbig hinterlegt nach Last.
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    required property var sys              // System.qml
    property string search: ""
    signal runTaskRequested()
    signal contextMenuRequested(var entries, real x, real y)
    signal showDetails(int pid)

    property string sortKey: "cpu"
    property bool sortDesc: true
    property string selectedKey: ""
    property var selectedPids: []
    property string selectedName: ""
    property var expanded: ({})

    readonly property real memTotal: sys.mem.total || 1
    readonly property real diskActive: Math.max(0, ...Object.values(sys.diskStats).map(d => d.active))

    readonly property var columns: [
        { key: "name", label: tr.t("tm.name"), width: 0, align: "left" },
        { key: "cpu",  label: "CPU", width: 110, align: "right", summary: Math.round(sys.cpu * 100) + " %" },
        { key: "mem",  label: tr.t("tm.memory"), width: 140, align: "right",
          summary: Math.round((sys.mem.used || 0) / memTotal * 100) + " %" },
        { key: "disk", label: tr.t("tm.disk"), width: 120, align: "right", summary: Math.round(diskActive * 100) + " %" }
    ]

    ListModel { id: rowModel }

    // ---- Zeilen bauen ----
    function appInfo(cls, title) {
        const e = cls ? DesktopEntries.heuristicLookup(cls) : null
        return { name: e ? e.name : (cls || title || tr.t("tm.app")), icon: e ? e.icon : cls }
    }
    function rebuild() {
        const procs = sys.processes
        const byPid = {}, kids = {}
        for (const p of procs) { byPid[p.pid] = p; (kids[p.ppid] = kids[p.ppid] || []).push(p.pid) }

        // Fenster → Apps
        const wins = {}
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject || {}
            if (!o.pid || o.pid <= 0) continue
            if (!wins[o.pid]) wins[o.pid] = { cls: o.class || o.initialClass || "", title: o.title || "", count: 0 }
            wins[o.pid].count++
        }
        const assigned = {}
        const apps = []
        for (const wp in wins) {
            if (!byPid[wp]) continue
            const members = []
            const stack = [+wp]
            while (stack.length) {
                const pid = stack.pop()
                if (assigned[pid]) continue
                if (pid !== +wp && wins[pid]) continue          // eigene App
                assigned[pid] = true
                members.push(byPid[pid])
                for (const c of (kids[pid] || [])) stack.push(c)
            }
            const info = appInfo(wins[wp].cls, wins[wp].title)
            apps.push({ key: "app:" + wp, name: info.name, icon: info.icon || "", members: members,
                        cpu: members.reduce((s, m) => s + m.cpu, 0),
                        mem: members.reduce((s, m) => s + m.mem, 0),
                        disk: members.reduce((s, m) => s + m.disk, 0) })
        }

        const q = root.search.trim().toLowerCase()
        const match = (name, pids) => !q || name.toLowerCase().indexOf(q) >= 0 || pids.some(p => String(p).indexOf(q) === 0)
        const cmp = (a, b) => {
            let r = root.sortKey === "name" ? a.name.localeCompare(b.name) : (a[root.sortKey] - b[root.sortKey])
            if (root.sortKey !== "name" && root.sortDesc) r = -r
            if (root.sortKey === "name" && root.sortDesc) r = -r
            return r
        }

        const bg = [], system = []
        for (const p of procs) {
            if (assigned[p.pid] || p.kernel) continue
            const e = { key: "pid:" + p.pid, name: p.name, icon: "", members: [p], cpu: p.cpu, mem: p.mem, disk: p.disk }
            if (p.uid === sys.myUid) bg.push(e); else system.push(e)
        }

        const rows = []
        const row = (o) => Object.assign({ type: "proc", key: "", name: "", icon: "", cpu: 0, mem: 0, disk: 0,
                                           pids: "", count: 0, depth: 0, expandable: false, open: false }, o)
        const section = (label, list, isApp) => {
            const shown = list.filter(a => match(a.name, a.members.map(m => m.pid))).sort(cmp)
            if (!shown.length) return
            rows.push(row({ type: "header", key: "h:" + label, name: label + " (" + shown.length + ")" }))
            for (const a of shown) {
                const open = !!root.expanded[a.key]
                rows.push(row({ type: isApp ? "app" : "proc", key: a.key, name: a.name, icon: a.icon,
                                cpu: a.cpu, mem: a.mem, disk: a.disk, pids: a.members.map(m => m.pid).join(","),
                                count: a.members.length, expandable: isApp && a.members.length > 1, open: open }))
                if (isApp && open && a.members.length > 1)
                    for (const m of a.members.slice().sort((x, y) => y.cpu - x.cpu))
                        rows.push(row({ type: "child", key: a.key + ":" + m.pid, name: m.name + "  ·  " + m.pid,
                                        cpu: m.cpu, mem: m.mem, disk: m.disk, pids: String(m.pid), depth: 1 }))
            }
        }
        section(tr.t("tm.apps"), apps, true)
        section(tr.t("tm.backgroundProcesses"), bg, false)
        section(tr.t("tm.systemProcesses"), system, false)
        Model.sync(rowModel, rows)

        // Auswahl aktualisieren (Prozesse können verschwinden)
        const sel = rows.find(r => r.key === root.selectedKey)
        if (sel) root.selectedPids = sel.pids.split(",").map(Number)
        else if (root.selectedKey) { root.selectedKey = ""; root.selectedPids = []; root.selectedName = "" }
    }
    Connections { target: root.sys; function onProcessesChanged() { root.rebuild() } }
    onSearchChanged: rebuild()
    onSortKeyChanged: rebuild()
    onSortDescChanged: rebuild()
    onExpandedChanged: rebuild()

    function endTask() { if (selectedPids.length) sys.kill(selectedPids, false) }

    // ---- Tastatur: Pfeile wählen Prozesse (Überschriften werden übersprungen) ----
    // Rechts/Links klappt Apps auf/zu, Enter auch; Entf beendet (TaskManagerContent)
    function selectable(i) { return rowModel.get(i).type !== "header" }
    function currentRow() {
        for (let i = 0; i < rowModel.count; i++) if (rowModel.get(i).key === selectedKey) return i
        return -1
    }
    function selectRow(i) {
        const r = rowModel.get(i)
        selectedKey = r.key
        selectedPids = r.pids.split(",").map(Number)
        selectedName = r.name
        list.positionViewAtIndex(i, ListView.Contain)
    }
    function toggle(key) { const e = Object.assign({}, expanded); e[key] = !e[key]; expanded = e }

    // Farbe nach Last (wie die gelben Felder bei Windows, hier in der Akzentfarbe)
    function heat(v) { return Theme.alpha(Theme.primary, Math.min(0.45, Math.max(0, v) * 0.45)) }

    // ===== Kopf =====
    PageHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: tr.t("tm.processes")
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
            enabled: root.selectedPids.length > 0
            onClicked: root.endTask()
        }
    }

    TableHeader {
        id: tableHead
        anchors { left: parent.left; right: parent.right; top: head.bottom }
        anchors.rightMargin: 12
        columns: root.columns
        sortKey: root.sortKey
        sortDesc: root.sortDesc
        onSortRequested: (k) => { if (root.sortKey === k) root.sortDesc = !root.sortDesc; else { root.sortKey = k; root.sortDesc = k !== "name" } }
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
        onActiveFocusChanged: if (activeFocus && !root.selectedKey) {
            const i = FocusNav.firstIndex(rowModel.count, root.selectable)
            if (i >= 0) root.selectRow(i)
        }
        Keys.onPressed: (e) => {
            const cur = root.currentRow()
            const i = FocusNav.listKey(e, rowModel.count, cur, root.selectable)
            if (i >= 0) { root.selectRow(i); e.accepted = true; return }
            if (cur < 0 || (e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) return
            const r = rowModel.get(cur)
            const exp = r.type === "app" && r.expandable
            if (e.key === Qt.Key_Right && exp && !r.open) { root.toggle(r.key); e.accepted = true }
            else if (e.key === Qt.Key_Left && exp && r.open) { root.toggle(r.key); e.accepted = true }
            else if (e.key === Qt.Key_Left && r.type === "child") {                  // Kind → zur App
                for (let j = cur - 1; j >= 0; j--) if (rowModel.get(j).type === "app") { root.selectRow(j); break }
                e.accepted = true
            }
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && exp) { root.toggle(r.key); e.accepted = true }
        }

        delegate: Item {
            id: rowItem
            required property int index
            required property string type
            required property string key
            required property string name
            required property string icon
            required property real cpu
            required property real mem
            required property real disk
            required property string pids
            required property int count
            required property int depth
            required property bool expandable
            required property bool open

            width: list.width - 12
            height: type === "header" ? 40 : 36
            readonly property bool selected: root.selectedKey === key && type !== "header"

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                radius: Theme.radiusMd
                color: rowItem.selected ? Theme.alpha(Theme.primary, 0.14) : "transparent"
                HoverLayer { shown: mouse.containsMouse && rowItem.type !== "header"; level: 0.6 }
            }

            // Abschnitt (Apps, Hintergrundprozesse …)
            Text {
                visible: rowItem.type === "header"
                x: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: rowItem.name
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.DemiBold
            }

            Row {
                visible: rowItem.type !== "header"
                anchors.fill: parent

                // Name
                Item {
                    width: parent.width - 110 - 140 - 120
                    height: parent.height
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12 + rowItem.depth * 28
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Text {
                            width: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowItem.expandable ? String.fromCodePoint(rowItem.open ? 0xF0140 : 0xF0142) : ""
                            color: Theme.mutedForeground
                            font.family: Theme.fontIcon; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: rowItem.expandable; onClicked: root.toggle(rowItem.key) }
                        }
                        Item {
                            width: 18; height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: appImg
                                anchors.fill: parent
                                source: rowItem.icon ? Quickshell.iconPath(rowItem.icon, true) : ""
                                sourceSize: Qt.size(36, 36)
                                visible: status === Image.Ready
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !appImg.visible
                                text: String.fromCodePoint(rowItem.type === "app" ? 0xF05AF : 0xF061A)
                                color: Theme.mutedForeground
                                font.family: Theme.fontIcon; font.pixelSize: 15
                            }
                        }
                        Text {
                            width: parent.width - 16 - 18 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: rowItem.name + (rowItem.type === "app" && rowItem.count > 1 ? "  (" + rowItem.count + ")" : "")
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                        }
                    }
                }
                // Werte
                Repeater {
                    model: [
                        { w: 110, v: rowItem.cpu, t: I18n.formatNumber(rowItem.cpu * 100, 1) + " %" },
                        { w: 140, v: rowItem.mem / root.memTotal * 4, t: root.sys.bytes(rowItem.mem) },
                        { w: 120, v: rowItem.disk / (20 * 1024 * 1024), t: rowItem.disk > 0 ? root.sys.rate(rowItem.disk) : root.sys.rate(0) }
                    ]
                    Rectangle {
                        required property var modelData
                        width: modelData.w
                        height: rowItem.height
                        color: root.heat(modelData.v)
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.t
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                enabled: rowItem.type !== "header"
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (e) => {
                    root.selectedKey = rowItem.key
                    root.selectedPids = rowItem.pids.split(",").map(Number)
                    root.selectedName = rowItem.name
                    list.forceActiveFocus()                  // danach mit Pfeilen weiter
                    if (e.button === Qt.RightButton) {
                        const p = mapToItem(root, e.x, e.y)
                        const entries = [
                            { label: tr.t("tm.endTask"), icon: String.fromCodePoint(0xF0156), action: "end" },
                            { label: tr.t("tm.endImmediatelyForce"), icon: String.fromCodePoint(0xF0028), action: "kill", variant: "destructive" },
                            { type: "separator" }
                        ]
                        if (rowItem.expandable) entries.push({ label: rowItem.open ? tr.t("tm.collapse") : tr.t("tm.expand"), action: "toggle" })
                        entries.push({ label: tr.t("tm.openFileLocation"), icon: String.fromCodePoint(0xF0770), action: "location" })
                        entries.push({ label: tr.t("tm.showDetails"), icon: String.fromCodePoint(0xF0279), action: "details" })
                        root.contextMenuRequested(entries, p.x, p.y)
                    }
                }
                onDoubleClicked: if (rowItem.expandable) root.toggle(rowItem.key)
            }
        }
    }

    // Aktionen aus dem Kontextmenü
    function menuAction(a) {
        if (a === "end") sys.kill(selectedPids, false)
        else if (a === "kill") sys.kill(selectedPids, true)
        else if (a === "toggle") toggle(selectedKey)
        else if (a === "details" && selectedPids.length) showDetails(selectedPids[0])
        else if (a === "location" && selectedPids.length) sys.openLocation(selectedPids[0])
    }

    Component.onCompleted: rebuild()
}
