import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Etude.Ui
import "../components"
import "../FileIcons.js" as Icons
import "../components/DropUtil.js" as DropUtil

// Inhalt eines Ordners als Raster (mit Vorschaubildern) oder Liste (Name, Datum, Typ, Größe).
// Klick wählt aus (Strg = mehrere, Umschalt = Bereich), Doppelklick/Enter öffnet,
// Rechtsklick öffnet das Kontextmenü (auf einem Element oder auf freier Fläche),
// F2 benennt direkt in der Ansicht um.
FocusScope {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    property string path: ""
    property string viewMode: "grid"       // "grid" | "list"
    property string sortKey: "name"        // "name" | "date" | "type" | "size"
    property bool sortDesc: false
    property bool showHidden: false
    property string search: ""
    property var cutPaths: []              // ausgeschnittene Elemente (blass dargestellt)

    property var selected: ({})            // Pfad → true
    property int anchorIndex: -1
    property string renaming: ""           // Pfad, der gerade umbenannt wird
    property string pendingSelect: ""      // nach dem Anlegen/Umbenennen auswählen
    property bool pendingRename: false

    readonly property var selectedPaths: Object.keys(selected).filter(p => selected[p])
    readonly property int count: folderModel.count
    // ausgewählte Ordner (Pfad → true), damit z. B. der Detailbereich sofort weiß, was ein Ordner ist
    readonly property var selectedDirs: {
        const out = {}
        for (let i = 0; i < folderModel.count; i++) {
            const p = folderModel.get(i, "filePath")
            if (selected[p] && folderModel.get(i, "fileIsDir")) out[p] = true
        }
        return out
    }
    readonly property real selectedSize: {
        let s = 0
        for (let i = 0; i < folderModel.count; i++) {
            const p = folderModel.get(i, "filePath")
            if (selected[p] && !folderModel.get(i, "fileIsDir")) s += folderModel.get(i, "fileSize")
        }
        return s
    }

    signal openPath(string path, bool isDir)
    signal sortChangeRequested(string key, bool desc)
    signal itemMenuRequested(real x, real y)          // Auswahl steht in selectedItems()
    signal backgroundMenuRequested(real x, real y)
    signal renameRequested(string path, string name)
    signal action(string name)                        // Tastenkürzel: copy, cut, paste, trash, delete, rename, newFolder, properties
    signal dropRequested(var paths, string dest, bool copy)   // Ziehen und Ablegen
    signal openInNewTab(string path)                  // mittlere Maustaste auf einem Ordner

    // ---- Ziehen und Ablegen ----
    // Ziehen startet einen echten Wayland-Drag (text/uri-list): Ablegen geht in Ordner,
    // in die Sidebar, auf Tabs, in andere Explorer-Fenster und in andere Apps.
    property var dragPaths: []                        // gerade gezogene Elemente
    property bool dragStarting: false
    property point pressPos: Qt.point(0, 0)
    property var dragItems: []                        // für das Vorschaubild
    function startDrag(index, path) {
        if (dragStarting) return
        if (!selected[path]) clickItem(index, path, 0)
        const items = selectedItems()
        if (!items.length) return
        dragStarting = true
        dragPaths = items.map(i => i.path)
        dragItems = items
        dragProxy.Drag.mimeData = {
            "text/uri-list": dragPaths.map(p => "file://" + encodeURI(p)).join("\r\n") + "\r\n",
            "text/plain": dragPaths.join("\n")
        }
        // Vorschaubild: Icon + Anzahl, als Bild abfotografiert und dem Drag mitgegeben
        dragBadge.visible = true
        Qt.callLater(() => dragBadge.grabToImage((result) => {
            dragProxy.Drag.imageSource = result.url
            dragBadge.visible = false
            dragProxy.Drag.active = true
            root.dragStarting = false
        }, Qt.size(dragBadge.width * 2, dragBadge.height * 2)))
    }
    Item {
        id: dragProxy
        visible: false
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot: Qt.point(28, 28)
        Drag.onDragFinished: (action) => { dragProxy.Drag.active = false; root.dragPaths = []; root.dragItems = [] }
    }
    // Vorschau beim Ziehen: Icon (bei mehreren gestapelt) und eine Zahl
    Item {
        id: dragBadge
        visible: false
        x: -400; y: -400
        width: 120; height: 76
        Rectangle {
            visible: root.dragItems.length > 1
            x: 8; y: 4
            width: 56; height: 56
            radius: Theme.radiusLg
            color: Theme.alpha(Theme.popover, 0.9)
            border.width: 1
            border.color: Theme.border
            rotation: 6
        }
        Rectangle {
            x: 4; y: 4
            width: 56; height: 56
            radius: Theme.radiusLg
            color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 0.95)
            border.width: 1
            border.color: Theme.alpha(Theme.primary, 0.6)
            FileIcon {
                anchors.centerIn: parent
                size: 40
                name: root.dragItems.length ? root.dragItems[0].name : ""
                path: root.dragItems.length ? root.dragItems[0].path : ""
                isDir: root.dragItems.length ? root.dragItems[0].isDir : false
                thumbnail: true
            }
        }
        Rectangle {
            visible: root.dragItems.length > 1
            x: 46; y: 0
            width: Math.max(22, countText.implicitWidth + 10); height: 22
            radius: 11
            color: Theme.primary
            Text {
                id: countText
                anchors.centerIn: parent
                text: root.dragItems.length
                color: Theme.primaryForeground
                font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.DemiBold
            }
        }
        Rectangle {
            x: 4; y: 62
            width: Math.min(116, nameText.implicitWidth + 12); height: 14
            radius: 4
            color: Theme.alpha(Theme.primary, 0.9)
            Text {
                id: nameText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 104)
                elide: Text.ElideRight
                text: root.dragItems.length === 1 ? root.dragItems[0].name : root.dragItems.length + " Elemente"
                color: Theme.primaryForeground
                font.family: Theme.fontSans; font.pixelSize: 10
            }
        }
    }
    // Strg = kopieren, sonst verschieben (wie Windows innerhalb eines Laufwerks)
    function dropInto(drop, dest) {
        const paths = DropUtil.paths(drop).filter(p => p !== dest)
        if (!paths.length) return
        drop.acceptProposedAction()
        root.dropRequested(paths, dest, DropUtil.isCopy(drop))
    }

    onPathChanged: { selected = ({}); anchorIndex = -1; renaming = "" }

    FolderListModel {
        id: folderModel
        folder: root.path ? "file://" + root.path : ""
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        caseSensitive: false
        sortCaseSensitive: false
        nameFilters: root.search.trim() ? ["*" + root.search.trim() + "*"] : []
        sortField: root.sortKey === "date" ? FolderListModel.Time : root.sortKey === "size" ? FolderListModel.Size
                 : root.sortKey === "type" ? FolderListModel.Type : FolderListModel.Name
        sortReversed: root.sortDesc
        onCountChanged: { root.pruneSelection(); root.applyPending() }
        onStatusChanged: root.applyPending()
    }

    // ---- Auswahl ----
    // gelöschte/verschobene Elemente fliegen aus der Auswahl (sonst zeigt z. B. der Detailbereich sie weiter)
    function pruneSelection() {
        if (!selectedPaths.length) return
        const exist = {}
        for (let i = 0; i < folderModel.count; i++) exist[folderModel.get(i, "filePath")] = true
        const keep = {}
        let changed = false
        for (const p of selectedPaths) { if (exist[p]) keep[p] = true; else changed = true }
        if (changed) selected = keep
    }
    function indexOf(path) {
        for (let i = 0; i < folderModel.count; i++) if (folderModel.get(i, "filePath") === path) return i
        return -1
    }
    function selectedItems() {
        const out = []
        for (let i = 0; i < folderModel.count; i++) {
            const p = folderModel.get(i, "filePath")
            if (selected[p]) out.push({ path: p, name: folderModel.get(i, "fileName"), isDir: folderModel.get(i, "fileIsDir") })
        }
        return out
    }
    function clickItem(index, path, mods) {
        if (renaming && renaming !== path) commitRename()
        if (mods & Qt.ControlModifier) {
            const s = Object.assign({}, selected); s[path] = !s[path]; selected = s
            anchorIndex = index
        } else if ((mods & Qt.ShiftModifier) && anchorIndex >= 0) {
            const s = {}
            const a = Math.min(anchorIndex, index), b = Math.max(anchorIndex, index)
            for (let i = a; i <= b; i++) s[folderModel.get(i, "filePath")] = true
            selected = s
        } else {
            const s = {}; s[path] = true; selected = s
            anchorIndex = index
        }
        currentView().currentIndex = index
    }
    function selectOnly(path) {
        const i = indexOf(path)
        if (i < 0) return false
        const s = {}; s[path] = true; selected = s
        anchorIndex = i
        currentView().currentIndex = i
        currentView().positionViewAtIndex(i, ListView.Contain)
        return true
    }
    function selectAll() {
        const s = {}
        for (let i = 0; i < folderModel.count; i++) s[folderModel.get(i, "filePath")] = true
        selected = s
    }
    function currentView() { return root.viewMode === "grid" ? grid : list }
    function openCurrent() {
        const i = currentView().currentIndex
        if (i < 0 || i >= folderModel.count) return
        root.openPath(folderModel.get(i, "filePath"), folderModel.get(i, "fileIsDir"))
    }

    // ---- Umbenennen ----
    function startRename(path) {
        if (!path) { const it = selectedItems(); if (it.length !== 1) return; path = it[0].path }
        if (!selectOnly(path)) return
        renaming = path
    }
    function commitRename() {
        const p = renaming
        if (!p) return
        renaming = ""
        if (renameText.length) root.renameRequested(p, renameText)
        root.forceActiveFocus()
    }
    property string renameText: ""
    // nach dem Anlegen/Umbenennen: Element auswählen (sobald es in der Liste steht)
    function selectWhenReady(path, rename) { pendingSelect = path; pendingRename = rename; applyPending() }
    function applyPending() {
        if (!pendingSelect) return
        if (selectOnly(pendingSelect)) {
            const p = pendingSelect, r = pendingRename
            pendingSelect = ""; pendingRename = false
            if (r) renaming = p
        }
    }

    // ---- Tastatur ----
    // Pfeile in der Ansicht: Auswahl wandern lassen (wie Explorer), Shift erweitert, Pos1/Ende
    // per Tastatur in die Ansicht gekommen, nichts ausgewählt → aktuelles (bzw. erstes) Element auswählen
    function keyboardEnter(view) {
        if (renaming || folderModel.count === 0 || selectedPaths.length) return
        const i = view.currentIndex >= 0 && view.currentIndex < folderModel.count ? view.currentIndex : 0
        clickItem(i, folderModel.get(i, "filePath"), 0)
        view.positionViewAtIndex(i, view === grid ? GridView.Contain : ListView.Contain)
    }
    function arrowKey(view, e) {
        if (renaming || folderModel.count === 0) return
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
        const k = e.key
        const before = view.currentIndex
        const isArrow = k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Left || k === Qt.Key_Right
        // nichts ausgewählt (z. B. per Tab gekommen): erster Pfeil wählt das aktuelle Element, statt zu springen
        if (isArrow && selectedPaths.length === 0 && before >= 0 && before < folderModel.count) {
            keyboardEnter(view); e.accepted = true; return
        }
        if (before < 0 && (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Left || k === Qt.Key_Right)) view.currentIndex = 0
        else if (k === Qt.Key_Home) view.currentIndex = 0
        else if (k === Qt.Key_End) view.currentIndex = folderModel.count - 1
        else if (view === grid && k === Qt.Key_Left) grid.moveCurrentIndexLeft()
        else if (view === grid && k === Qt.Key_Right) grid.moveCurrentIndexRight()
        else if (view === grid && k === Qt.Key_Up) grid.moveCurrentIndexUp()
        else if (view === grid && k === Qt.Key_Down) grid.moveCurrentIndexDown()
        else if (view === list && k === Qt.Key_Up) list.decrementCurrentIndex()
        else if (view === list && k === Qt.Key_Down) list.incrementCurrentIndex()
        else return                                       // nicht unsere Taste
        const i = view.currentIndex
        if (i === before) { e.accepted = false; return }  // Rand: weiter zum Nachbarn (Pfeil-Navigation)
        clickItem(i, folderModel.get(i, "filePath"), e.modifiers & Qt.ShiftModifier)
        view.positionViewAtIndex(i, view === grid ? GridView.Contain : ListView.Contain)
        e.accepted = true
    }
    Keys.onPressed: (e) => {
        if (renaming) return
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (e.modifiers & Qt.AltModifier) root.action("properties"); else openCurrent()
        }
        else if (ctrl && e.key === Qt.Key_A) selectAll()
        else if (ctrl && e.key === Qt.Key_C) root.action("copy")
        else if (ctrl && e.key === Qt.Key_X) root.action("cut")
        else if (ctrl && e.key === Qt.Key_V) root.action("paste")
        else if (ctrl && shift && e.key === Qt.Key_N) root.action("newFolder")
        else if (ctrl && e.key === Qt.Key_Z) root.action("undo")
        else if (e.key === Qt.Key_F2) startRename("")
        else if (e.key === Qt.Key_Delete) root.action(shift ? "delete" : "trash")
        else if (e.key === Qt.Key_Escape && selectedPaths.length) selected = ({})
        else return
        e.accepted = true
    }

    // Ablegen auf freier Fläche → in diesen Ordner
    DropArea {
        id: bgDrop
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]
        onEntered: (drag) => { if (root.dragPaths.length && root.dragPaths.every(p => p.slice(0, p.lastIndexOf("/")) === root.path)) drag.accepted = false }
        onDropped: (drop) => root.dropInto(drop, root.path)
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        visible: bgDrop.containsDrag
        color: "transparent"
        radius: Theme.radiusLg
        border.width: 2
        border.color: Theme.alpha(Theme.primary, 0.5)
        z: 20
    }

    // Freie Fläche: Linksklick hebt die Auswahl auf, Rechtsklick öffnet das Ordner-Menü
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => {
            if (root.renaming) root.commitRename()
            root.selected = ({})
            root.forceActiveFocus()
            if (e.button === Qt.RightButton) root.backgroundMenuRequested(e.x, e.y)
        }
    }

    Text {
        visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
        anchors.centerIn: parent
        text: root.search.trim() ? tr.t("files.noMatches").arg(root.search.trim()) : tr.t("files.folderEmpty")
        color: Theme.mutedForeground
        font.family: Theme.fontSans; font.pixelSize: 14
    }

    // Eingabefeld zum Umbenennen (liegt über dem Namen des Elements)
    Component {
        id: renameEditor
        Input {
            id: ed
            // es wird immer nur ein Element umbenannt → Pfad und Name aus root.renaming
            readonly property string itemPath: root.renaming
            readonly property string itemName: itemPath.slice(itemPath.lastIndexOf("/") + 1)
            fontSize: 12
            implicitHeight: 26
            Component.onCompleted: {
                startedFor = itemPath
                text = itemName
                root.renameText = itemName
                forceActiveFocus()
                const dot = itemName.lastIndexOf(".")
                if (dot > 0) select(0, dot); else selectAll()
            }
            onTextChanged: root.renameText = text
            onAccepted: root.commitRename()
            onEscapePressed: { root.renaming = ""; root.forceActiveFocus() }
            property string startedFor: ""
            onActiveFocusChanged: if (!activeFocus && root.renaming !== "" && root.renaming === startedFor) root.commitRename()
        }
    }

    // ===== Liste: Spaltenkopf =====
    TableHeader {
        id: listHead
        visible: root.viewMode === "list"
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 24 }
        columns: [
            { key: "name", label: tr.t("files.name"), width: 0, align: "left" },
            { key: "date", label: tr.t("files.dateModified"), width: 170, align: "left" },
            { key: "type", label: tr.t("files.type"), width: 160, align: "left" },
            { key: "size", label: tr.t("files.size"), width: 100, align: "right" }
        ]
        sortKey: root.sortKey
        sortDesc: root.sortDesc
        onSortRequested: (k) => root.sortChangeRequested(k, root.sortKey === k ? !root.sortDesc : (k === "date" || k === "size"))
    }

    // ===== Raster =====
    GridView {
        id: grid
        visible: root.viewMode === "grid"
        anchors { fill: parent; leftMargin: 16; rightMargin: 8; topMargin: 12 }
        clip: true
        model: root.viewMode === "grid" ? folderModel : null
        cellWidth: 116
        cellHeight: 124
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        focus: root.viewMode === "grid"
        activeFocusOnTab: root.viewMode === "grid"     // per Tab/Pfeil erreichbar (eine Station, wie bei Windows)
        currentIndex: -1
        // Pfeile wählen aus (Shift erweitert); am Rand geht es weiter zum Nachbarn (FocusRoot)
        Keys.onPressed: (e) => root.arrowKey(grid, e)
        property bool _tabbed: false                   // per Pfeil/Tastatur betreten (FocusNav)
        onActiveFocusChanged: if (activeFocus && _tabbed) { _tabbed = false; root.keyboardEnter(grid) }

        delegate: Item {
            id: cell
            required property int index
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool sel: !!root.selected[filePath]
            readonly property bool editing: root.renaming === filePath
            opacity: root.cutPaths.indexOf(filePath) >= 0 || root.dragPaths.indexOf(filePath) >= 0 ? 0.45 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: Theme.radiusLg
                color: cellDrop.containsDrag ? Theme.alpha(Theme.primary, 0.24) : cell.sel ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                border.width: cell.sel || cellDrop.containsDrag ? 1 : 0
                border.color: Theme.alpha(Theme.primary, cellDrop.containsDrag ? 0.8 : 0.4)
                HoverLayer { shown: mouse.containsMouse && !cell.sel; level: 0.6 }
            }
            FileIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                size: 64
                name: cell.fileName
                path: cell.filePath
                isDir: cell.fileIsDir
                thumbnail: true
            }
            Text {
                visible: !cell.editing
                anchors.top: icon.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                text: cell.fileName
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 12
            }
            // Ordner nehmen abgelegte Elemente auf
            DropArea {
                id: cellDrop
                anchors.fill: parent
                enabled: cell.fileIsDir && root.dragPaths.indexOf(cell.filePath) < 0
                keys: ["text/uri-list", "text/plain"]
                onDropped: (drop) => root.dropInto(drop, cell.filePath)
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !cell.editing
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: (e) => root.pressPos = mapToItem(root, e.x, e.y)
                onPositionChanged: (e) => {
                    if (!(e.buttons & Qt.LeftButton) || root.dragPaths.length || root.dragStarting) return
                    const p = mapToItem(root, e.x, e.y)
                    if (Math.abs(p.x - root.pressPos.x) + Math.abs(p.y - root.pressPos.y) > 10) root.startDrag(cell.index, cell.filePath)
                }
                onClicked: (e) => {
                    root.forceActiveFocus()
                    if (e.button === Qt.MiddleButton) { if (cell.fileIsDir) root.openInNewTab(cell.filePath) }
                    else if (e.button === Qt.RightButton) {
                        if (!root.selected[cell.filePath]) root.clickItem(cell.index, cell.filePath, 0)
                        const p = mapToItem(root, e.x, e.y)
                        root.itemMenuRequested(p.x, p.y)
                    } else root.clickItem(cell.index, cell.filePath, e.modifiers)
                }
                onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) root.openPath(cell.filePath, cell.fileIsDir) }
            }
            Loader {
                active: cell.editing
                anchors.top: icon.bottom
                anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 6
                z: 5
                sourceComponent: renameEditor
            }
        }
    }

    // ===== Liste =====
    ListView {
        id: list
        visible: root.viewMode === "list"
        anchors { left: parent.left; right: parent.right; top: listHead.bottom; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        clip: true
        model: root.viewMode === "list" ? folderModel : null
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        focus: root.viewMode === "list"
        activeFocusOnTab: root.viewMode === "list"
        currentIndex: -1
        Keys.onPressed: (e) => root.arrowKey(list, e)
        property bool _tabbed: false
        onActiveFocusChanged: if (activeFocus && _tabbed) { _tabbed = false; root.keyboardEnter(list) }

        delegate: Item {
            id: row
            required property int index
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property var fileModified
            required property var fileSize
            width: list.width - 12
            height: 34
            readonly property bool sel: !!root.selected[filePath]
            readonly property bool editing: root.renaming === filePath
            opacity: root.cutPaths.indexOf(filePath) >= 0 || root.dragPaths.indexOf(filePath) >= 0 ? 0.45 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: rowDrop.containsDrag ? Theme.alpha(Theme.primary, 0.24) : row.sel ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                border.width: rowDrop.containsDrag ? 1 : 0
                border.color: Theme.alpha(Theme.primary, 0.8)
                HoverLayer { shown: mouse.containsMouse && !row.sel; level: 0.6 }
            }
            Row {
                anchors.fill: parent
                Item {
                    id: nameCell
                    width: row.width - 430
                    height: row.height
                    FileIcon {
                        id: rowIcon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        size: 20
                        name: row.fileName
                        path: row.filePath
                        isDir: row.fileIsDir
                    }
                    Text {
                        visible: !row.editing
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: row.fileName
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 13
                    }
                }
                Repeater {
                    model: [
                        { w: 170, t: Qt.formatDateTime(row.fileModified, tr.t("files.dateTimeShort")), r: false },
                        { w: 160, t: Icons.typeLabel(row.fileName, row.fileIsDir, tr), r: false },
                        { w: 100, t: row.fileIsDir ? "" : Icons.bytes(row.fileSize, I18n.locale.decimalPoint), r: true }
                    ]
                    Text {
                        required property var modelData
                        width: modelData.w
                        height: row.height
                        leftPadding: 12
                        rightPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: modelData.r ? Text.AlignRight : Text.AlignLeft
                        elide: Text.ElideRight
                        text: modelData.t
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans; font.pixelSize: 13
                        font.features: { "tnum": 1 }
                    }
                }
            }
            DropArea {
                id: rowDrop
                anchors.fill: parent
                enabled: row.fileIsDir && root.dragPaths.indexOf(row.filePath) < 0
                keys: ["text/uri-list", "text/plain"]
                onDropped: (drop) => root.dropInto(drop, row.filePath)
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !row.editing
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: (e) => root.pressPos = mapToItem(root, e.x, e.y)
                onPositionChanged: (e) => {
                    if (!(e.buttons & Qt.LeftButton) || root.dragPaths.length || root.dragStarting) return
                    const p = mapToItem(root, e.x, e.y)
                    if (Math.abs(p.x - root.pressPos.x) + Math.abs(p.y - root.pressPos.y) > 10) root.startDrag(row.index, row.filePath)
                }
                onClicked: (e) => {
                    root.forceActiveFocus()
                    if (e.button === Qt.MiddleButton) { if (row.fileIsDir) root.openInNewTab(row.filePath) }
                    else if (e.button === Qt.RightButton) {
                        if (!root.selected[row.filePath]) root.clickItem(row.index, row.filePath, 0)
                        const p = mapToItem(root, e.x, e.y)
                        root.itemMenuRequested(p.x, p.y)
                    } else root.clickItem(row.index, row.filePath, e.modifiers)
                }
                onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) root.openPath(row.filePath, row.fileIsDir) }
            }
            Loader {
                active: row.editing
                x: 42
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(360, nameCell.width - 50)
                z: 5
                sourceComponent: renameEditor
            }
        }
    }
}
