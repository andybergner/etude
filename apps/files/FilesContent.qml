import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Etude.Ui
import "components"
import "pages"

// Explorer – Aufbau wie Einstellungen und Task-Manager:
// Sidebar (Home, persönliche Ordner, angeheftete Ordner, Papierkorb, Laufwerke),
// Kopfzeile mit Zurück/Vor/Hoch, Adressleiste und Suche, Befehlsleiste, Ansicht, Statuszeile.
// Fast alles geht auch per Rechtsklick (Kontextmenüs auf Elementen, freier Fläche und Sidebar).
// Suche durchsucht auch Unterordner (SearchView), Detailbereich rechts (Alt+Umschalt+P),
// ZIP packen/entpacken, Rückgängig (Strg+Z), Fortschritt beim Kopieren großer Datenmengen.
Rectangle {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    property var places: null              // Places.qml
    property var ops: null                 // FileOps.qml
    property var apps: null                // Etude.Services/AppManager (Öffnen mit)
    property var config: null              // Etude.Services/EtudeConfig (angeheftete Ordner)

    // ---- Tabs (wie im Windows-11-Explorer) ----
    // Jeder Tab hat seinen Ort und seinen eigenen Verlauf für Zurück/Vor.
    property string initialLocation: Quickshell.env("HOME") || "/"
    property string initialSelect: ""      // Datei, die beim Start ausgewählt wird (z. B. „Dateispeicherort öffnen“)
    property var tabs: [{ loc: initialLocation, back: [], fwd: [] }]
    property int currentTab: 0
    readonly property var tab: tabs[Math.min(currentTab, tabs.length - 1)]
    readonly property string location: tab.loc              // absoluter Pfad oder "trash"
    readonly property var backStack: tab.back
    readonly property var forwardStack: tab.fwd
    signal closeWindow()

    property string viewMode: "grid"
    property string sortKey: "name"
    property bool sortDesc: false
    property bool showHidden: false

    property bool sidebarCollapsed: false
    readonly property bool compact: width < 860
    readonly property bool collapsed: sidebarCollapsed || compact
    readonly property bool isTrash: location === "trash"
    readonly property bool searching: !isTrash && searchInput.text.trim() !== ""
    readonly property bool showDetails: !!config && !!config.filesDetails && !compact
    readonly property string home: places ? places.home : ""
    readonly property var pinned: config ? (config.filesPinned || []) : []
    readonly property var view: pageLoader.item        // FolderView oder TrashView

    color: Theme.alpha(Theme.background, Theme.glassWindow)

    // ===================== Navigation =====================
    function setTab(obj) {
        const t = tabs.slice()
        t[currentTab] = Object.assign({}, t[currentTab], obj)
        tabs = t
        searchInput.text = ""
        editing = false
    }
    function go(loc) {
        if (!loc || loc === location) return
        setTab({ loc: loc, back: backStack.concat([location]), fwd: [] })
    }
    function back() {
        if (!backStack.length) return
        setTab({ loc: backStack[backStack.length - 1], back: backStack.slice(0, -1), fwd: forwardStack.concat([location]) })
    }
    function forward() {
        if (!forwardStack.length) return
        setTab({ loc: forwardStack[forwardStack.length - 1], back: backStack.concat([location]), fwd: forwardStack.slice(0, -1) })
    }
    function newTab(loc, background) {
        tabs = tabs.concat([{ loc: loc || home, back: [], fwd: [] }])
        if (!background) currentTab = tabs.length - 1
        searchInput.text = ""
    }
    function closeTab(i) {
        if (tabs.length <= 1) { root.closeWindow(); return }
        const t = tabs.slice()
        t.splice(i, 1)
        if (currentTab > i || currentTab >= t.length) currentTab = Math.max(0, currentTab - 1)
        tabs = t
    }
    function moveTab(from, to) {
        const t = tabs.slice()
        const [it] = t.splice(from, 1)
        t.splice(to, 0, it)
        // der aktive Tab bleibt aktiv, auch wenn er wandert
        const cur = currentTab === from ? to
                  : (from < currentTab && to >= currentTab) ? currentTab - 1
                  : (from > currentTab && to <= currentTab) ? currentTab + 1 : currentTab
        tabs = t
        currentTab = cur
    }
    function switchTab(i) { if (i >= 0 && i < tabs.length) { currentTab = i; searchInput.text = ""; editing = false } }
    function tabLabel(loc) {
        if (loc === "trash") return tr.t("files.recycleBin")
        if (loc === home) return tr.t("files.home")
        if (loc === "/") return tr.t("files.localDisk")
        return loc.split("/").pop()
    }
    function up() {
        if (isTrash || location === "/") return
        go(location.slice(0, location.lastIndexOf("/")) || "/")
    }
    function parentOf(p) { return p.slice(0, p.lastIndexOf("/")) || "/" }
    function openPath(path, isDir) {
        if (isDir) go(path)
        else openFile(path)
    }
    // Datei mit der Standard-App öffnen (dieselbe wie in Einstellungen › Apps › Standard-Apps).
    // Keine Standard-App, aber passende Apps → fragen (wie Windows); gar keine → xdg-open.
    function openFile(path) {
        if (!apps) { Quickshell.execDetached(["xdg-open", path]); return }
        ops.mimeOf(path, (mime) => {
            const a = apps.appById(apps.defaultFor(mime))
            if (a) ops.openWith(a, [path])
            else if (apps.appsFor(mime).length > 0) chooseApp(path, mime)
            else Quickshell.execDetached(["xdg-open", path])
        })
    }
    function chooseApp(path, mime) {
        appChooser.path = path
        appChooser.mime = mime
        const fit = apps ? apps.appsFor(mime) : []
        appChooser.selected = (apps && apps.defaultFor(mime)) || (fit.length ? fit[0].id : "")   // vorausgewählt wie bei Windows
        appChooser.showAll = false
        appChooser.open()
    }
    function openWindow(path) {
        Quickshell.execDetached(["etude-files", "--new-window", path])
    }
    // von außen (etude-files, während das Fenster schon offen ist): Ordner im neuen Tab, Datei auswählen
    function openExternal(path, select) {
        if (!path) return
        if (path !== location) newTab(path, false)
        if (select) Qt.callLater(() => { if (view && view.selectWhenReady) view.selectWhenReady(select, false) })
    }
    function openTerminal(path) { Quickshell.execDetached(["kitty", "--directory", path]) }
    function pin(path) { if (config && pinned.indexOf(path) < 0) config.set("filesPinned", pinned.concat([path])) }
    function unpin(path) { if (config) config.set("filesPinned", pinned.filter(p => p !== path)) }

    // ---- Adressleiste: Pfad als Brotkrumen, Klick daneben = Eingabe ----
    property bool editing: false
    readonly property var crumbs: {
        if (isTrash) return [{ label: tr.t("files.recycleBin"), path: "trash" }]
        const out = []
        let base = "", rest = location
        if (home && (location === home || location.startsWith(home + "/"))) {
            out.push({ label: tr.t("files.home"), path: home })
            base = home
            rest = location.slice(home.length)
        } else out.push({ label: tr.t("files.localDisk"), path: "/" })
        for (const part of rest.split("/").filter(x => x)) {
            base = (base === "/" ? "" : base) + "/" + part
            out.push({ label: part, path: base })
        }
        return out
    }
    function submitAddress(t) {
        t = t.trim().replace(/^~(?=\/|$)/, home).replace(/^file:\/\//, "")
        if (!t) { editing = false; return }
        checkDir.target = t
        checkDir.command = ["test", "-d", t]
        checkDir.running = true
    }
    Process {
        id: checkDir
        property string target: ""
        onExited: (code) => {
            if (code === 0) { root.go(target.replace(/\/+$/, "") || "/"); root.editing = false }
            else root.toast(tr.t("files.folderNotFound").arg(target))
        }
    }

    // ===================== Aktionen =====================
    function selItems() { return view && view.selectedItems ? view.selectedItems() : [] }
    function selPaths() { return selItems().map(i => i.path) }
    function doAction(a, arg) {
        const items = selItems()
        const paths = items.map(i => i.path)
        switch (a) {
        case "open":
            if (items.length === 1) openPath(items[0].path, items[0].isDir)
            else items.forEach(i => { if (!i.isDir) openFile(i.path) })
            break
        case "openWith":   ops.openWith(arg, paths); break
        case "chooseApp":  if (items.length === 1) ops.mimeOf(items[0].path, (m) => chooseApp(items[0].path, m)); break
        case "newWindow":  openWindow(arg || (items[0] ? items[0].path : location)); break
        case "newTab":     newTab(arg || (items[0] ? items[0].path : location), false); break
        case "copy":       ops.setClipboard(paths, false); break
        case "cut":        ops.setClipboard(paths, true); break
        case "paste":      ops.paste(arg || location); break
        case "rename":     if (view && view.startRename) view.startRename(""); break
        case "trash":      ops.trash(paths); break
        case "delete":     if (paths.length) { deleteDialog.paths = paths; deleteDialog.open() } break
        case "newFolder":  ops.newFolder(location); break
        case "newFile":    ops.newFile(location); break
        case "pin":        pin(arg); break
        case "unpin":      unpin(arg); break
        case "copyPath":   Quickshell.clipboardText = (arg ? [arg] : paths).join("\n"); break
        case "terminal":   openTerminal(arg || location); break
        case "properties": showProperties(arg ? [arg] : (paths.length ? paths : [location])); break
        case "view":       viewMode = arg; break
        case "sort":       sortKey = arg; sortDesc = arg === "date" || arg === "size"; break
        case "hidden":     showHidden = !showHidden; break
        case "restore":    ops.restore(view.selectedNames); break
        case "trashDelete": if (view.selectedNames.length) { deleteDialog.trashNames = view.selectedNames; deleteDialog.paths = []; deleteDialog.open() } break
        case "emptyTrash": emptyDialog.open(); break
        case "eject":      if (location.startsWith(arg.mount)) go(home); places.unmount(arg); break
        case "undo":       ops.undo(); break
        case "compress":   ops.compress(paths); break
        case "extract":    if (items.length === 1) ops.extract(items[0].path, arg || "folder"); break
        case "details":    if (config) config.set("filesDetails", !config.filesDetails); break
        case "openLocation":                   // aus der Suche: Ordner öffnen und Element auswählen
            if (items.length === 1) {
                const dir = parentOf(items[0].path)
                initialSelect = items[0].path
                if (dir === location) { searchInput.text = "" } else go(dir)
            }
            break
        }
    }

    // ---- Kontextmenüs ----
    function g(cp) { return String.fromCodePoint(cp) }
    function openWithEntries(path, mime) {
        if (!apps) return []
        const def = apps.defaultFor(mime)
        return apps.appsFor(mime).map(a => ({ label: a.id === def ? tr.t("files.defaultApp").arg(a.name) : a.name,
                                              action: "openWith", arg: a }))
            .concat([{ type: "separator" }, { label: tr.t("files.chooseAnotherApp"), icon: g(0xF0349), action: "chooseApp" }])
    }
    function itemMenu(x, y) {
        const items = selItems()
        if (!items.length) return
        const single = items.length === 1
        const dir = single && items[0].isDir
        const build = (mime) => {
            const e = [{ label: I18n.t("common.open"), icon: g(0xF0770), action: "open" }]
            if (single && !dir) {
                const w = openWithEntries(items[0].path, mime)
                if (apps) e.push({ label: tr.t("files.openWith"), icon: g(0xF003B), submenu: w })
            }
            if (dir) e.push({ label: tr.t("files.openInNewTab"), icon: g(0xF04E9), action: "newTab", arg: items[0].path },
                            { label: tr.t("files.openInNewWindow"), icon: g(0xF03CC), action: "newWindow", arg: items[0].path })
            if (single && searching) e.push({ label: tr.t("files.openFileLocation"), icon: g(0xF024B), action: "openLocation" })
            e.push({ type: "separator" },
                   { label: tr.t("files.cut"), icon: g(0xF0190), shortcut: tr.t("files.ctrlX"), action: "cut" },
                   { label: tr.t("files.copy"), icon: g(0xF018F), shortcut: tr.t("files.ctrlC"), action: "copy" })
            if (dir) e.push({ label: tr.t("files.paste"), icon: g(0xF0192), shortcut: tr.t("files.ctrlV"), action: "paste", arg: items[0].path, disabled: !ops.canPaste })
            e.push({ type: "separator" })
            if (single && !dir && ops.isArchive(items[0].path))
                e.push({ label: tr.t("files.extractAll"), icon: g(0xF125A), action: "extract", arg: "folder" },
                       { label: tr.t("files.extractHere"), icon: g(0xF125A), action: "extract", arg: "here" })
            e.push({ label: tr.t("files.compressToZipFile"), icon: g(0xF0FFA), action: "compress" },
                   { type: "separator" })
            if (single && !searching) e.push({ label: I18n.t("common.rename"), icon: g(0xF0455), shortcut: "F2", action: "rename" })
            e.push({ label: tr.t("files.moveToRecycleBin"), icon: g(0xF0A7A), shortcut: tr.t("files.del"), action: "trash" },
                   { label: tr.t("files.deletePermanently"), icon: g(0xF05E8), shortcut: tr.t("files.del2"), action: "delete", variant: "destructive" },
                   { type: "separator" })
            if (dir) e.push(pinned.indexOf(items[0].path) >= 0
                            ? { label: tr.t("files.unpinFromQuickAccess"), icon: g(0xF0931), action: "unpin", arg: items[0].path }
                            : { label: tr.t("files.pinToQuickAccess"), icon: g(0xF0403), action: "pin", arg: items[0].path })
            e.push({ label: tr.t("files.copyPath"), icon: g(0xF018F), action: "copyPath" },
                   { label: tr.t("files.openInTerminal"), icon: g(0xF018D), action: "terminal", arg: dir ? items[0].path : parentOf(items[0].path) },
                   { type: "separator" },
                   { label: tr.t("files.properties"), icon: g(0xF02FD), shortcut: tr.t("files.alt"), action: "properties" })
            showMenu(e, mapFromItem(view, x, y))
        }
        if (single && !dir) ops.mimeOf(items[0].path, build)
        else build("")
    }
    function backgroundMenu(x, y) {
        const undoEntry = ops.undoLabel ? [{ label: tr.t("files.undoWhat").arg(ops.undoLabel), icon: g(0xF054C), shortcut: tr.t("files.ctrlZ"), action: "undo" }, { type: "separator" }] : []
        showMenu(undoEntry.concat([
            { label: tr.t("files.new"), icon: g(0xF0415), submenu: [
                { label: tr.t("files.folder"), icon: g(0xF0257), shortcut: tr.t("files.ctrlN"), action: "newFolder" },
                { label: tr.t("files.textDocument"), icon: g(0xF0219), action: "newFile" } ] },
            { label: tr.t("files.paste"), icon: g(0xF0192), shortcut: tr.t("files.ctrlV"), action: "paste", disabled: !ops.canPaste },
            { type: "separator" },
            { label: tr.t("files.view"), icon: g(0xF0570), submenu: [
                { label: tr.t("files.largeIcons"), checked: viewMode === "grid", action: "view", arg: "grid" },
                { label: tr.t("files.details"), checked: viewMode === "list", action: "view", arg: "list" } ] },
            { label: tr.t("files.sortBy"), icon: g(0xF04BA), submenu: [
                { label: tr.t("files.name"), checked: sortKey === "name", action: "sort", arg: "name" },
                { label: tr.t("files.dateModified"), checked: sortKey === "date", action: "sort", arg: "date" },
                { label: tr.t("files.type"), checked: sortKey === "type", action: "sort", arg: "type" },
                { label: tr.t("files.size"), checked: sortKey === "size", action: "sort", arg: "size" } ] },
            { label: showHidden ? tr.t("files.hideHiddenItems") : tr.t("files.showHiddenItems"), icon: g(showHidden ? 0xF0209 : 0xF0208), shortcut: tr.t("files.ctrlH"), action: "hidden" },
            { type: "separator" },
            pinned.indexOf(location) >= 0
                ? { label: tr.t("files.unpinFromQuickAccess"), icon: g(0xF0931), action: "unpin", arg: location }
                : { label: tr.t("files.pinToQuickAccess"), icon: g(0xF0403), action: "pin", arg: location },
            { label: tr.t("files.openInTerminal"), icon: g(0xF018D), action: "terminal", arg: location },
            { type: "separator" },
            { label: tr.t("files.detailsPane"), checked: showDetails, icon: g(0xF06FE), shortcut: tr.t("files.altP"), action: "details" },
            { label: tr.t("files.properties"), icon: g(0xF02FD), action: "properties", arg: location }
        ]), mapFromItem(view, x, y))
    }
    function trashItemMenu(x, y) {
        showMenu([
            { label: tr.t("files.restore"), icon: g(0xF099B), action: "restore" },
            { label: tr.t("files.deletePermanently"), icon: g(0xF05E8), action: "trashDelete", variant: "destructive" }
        ], x < 0 ? Qt.point(main.x + main.width / 2, main.height / 2) : mapFromItem(view, x, y))
    }
    function trashBackgroundMenu(x, y) {
        showMenu([{ label: tr.t("files.emptyRecycleBin"), icon: g(0xF0A7A), action: "emptyTrash", variant: "destructive", disabled: !ops.trashItems.length }],
                 mapFromItem(view, x, y))
    }
    function sidebarMenu(path, pos, extra) {
        const e = [
            { label: I18n.t("common.open"), icon: g(0xF0770), action: "go", arg: path },
            { label: tr.t("files.openInNewTab"), icon: g(0xF04E9), action: "newTab", arg: path },
            { label: tr.t("files.openInNewWindow"), icon: g(0xF03CC), action: "newWindow", arg: path },
            { label: tr.t("files.openInTerminal"), icon: g(0xF018D), action: "terminal", arg: path }
        ]
        if (pinned.indexOf(path) >= 0) e.push({ type: "separator" }, { label: tr.t("files.unpinFromQuickAccess"), icon: g(0xF0931), action: "unpin", arg: path })
        if (extra) e.push({ type: "separator" }, extra)
        e.push({ type: "separator" }, { label: tr.t("files.properties"), icon: g(0xF02FD), action: "properties", arg: path })
        showMenu(e, pos)
    }

    // ===================== Tastatur =====================
    Keys.onPressed: (e) => {
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier
        if (alt && e.key === Qt.Key_Left) back()
        else if (alt && e.key === Qt.Key_Right) forward()
        else if (alt && e.key === Qt.Key_Up) up()
        else if (e.key === Qt.Key_Backspace && !searchInput.activeFocus && !addressInput.activeFocus) back()
        else if (ctrl && e.key === Qt.Key_L && !isTrash) { editing = true; addressInput.text = location; addressInput.forceActiveFocus() }
        else if (ctrl && e.key === Qt.Key_F) searchInput.forceActiveFocus()
        else if (ctrl && e.key === Qt.Key_B) sidebarCollapsed = !sidebarCollapsed
        else if (ctrl && e.key === Qt.Key_H) showHidden = !showHidden
        else if (ctrl && e.key === Qt.Key_N) openWindow(isTrash ? home : location)
        else if (ctrl && e.key === Qt.Key_T) newTab(home, false)
        else if (ctrl && e.key === Qt.Key_W) closeTab(currentTab)
        else if (ctrl && e.key === Qt.Key_Tab) switchTab((currentTab + 1) % tabs.length)
        else if (ctrl && e.key === Qt.Key_Backtab) switchTab((currentTab - 1 + tabs.length) % tabs.length)
        else if (ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) switchTab(e.key === Qt.Key_9 ? tabs.length - 1 : e.key - Qt.Key_1)
        else if (e.key === Qt.Key_F5) { places.refresh(); if (isTrash) ops.loadTrash() }
        else if (ctrl && e.key === Qt.Key_Z && !searchInput.activeFocus && !addressInput.activeFocus) ops.undo()
        else if (alt && (e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_P) doAction("details")
        else return
        e.accepted = true
    }

    // ===================== Tabs und Leisten (volle Breite) =====================
    // ---- Tabs ----
    TabBar {
        id: tabBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        tabs: root.tabs.map(t => ({ label: root.tabLabel(t.loc), loc: t.loc,
                                    icon: t.loc === "trash" ? 0xF0A7A : t.loc === root.home ? 0xF02DC : 0xF024B }))
        current: root.currentTab
        onActivated: (i) => root.switchTab(i)
        onCloseRequested: (i) => root.closeTab(i)
        onNewRequested: root.newTab(root.home, false)
        onMoved: (from, to) => root.moveTab(from, to)
        onDropped: (i, paths, copy) => {
            const loc = root.tabs[i].loc
            if (loc === "trash") root.ops.trash(paths); else root.dropTo(paths, loc, copy)
        }
    }

    // ---- Kopfzeile ----
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: tabBar.bottom }
        height: 56
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }

        Row {
            id: navButtons
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Button {
                variant: "ghost"; size: "icon-sm"
                iconStart: String.fromCodePoint(0xF06FD)
                enabled: !root.compact
                opacity: enabled ? 1 : 0.4
                onClicked: root.sidebarCollapsed = !root.sidebarCollapsed
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: Theme.border }
            Item { width: 2; height: 1 }
            Button { variant: "ghost"; size: "icon-sm"; iconStart: String.fromCodePoint(0xF004D); enabled: root.backStack.length > 0; opacity: enabled ? 1 : 0.4; onClicked: root.back() }
            Button { variant: "ghost"; size: "icon-sm"; iconStart: String.fromCodePoint(0xF0054); enabled: root.forwardStack.length > 0; opacity: enabled ? 1 : 0.4; onClicked: root.forward() }
            Button { variant: "ghost"; size: "icon-sm"; iconStart: String.fromCodePoint(0xF005D); enabled: !root.isTrash && root.location !== "/"; opacity: enabled ? 1 : 0.4; onClicked: root.up() }
        }

        Rectangle {
            id: address
            anchors.left: navButtons.right
            anchors.leftMargin: 8
            anchors.right: searchInput.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusMd
            color: root.editing ? "transparent" : Theme.alpha(Theme.muted, 0.5)
            border.width: root.editing ? 0 : 1
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                visible: !root.editing && !root.isTrash
                cursorShape: Qt.IBeamCursor
                onClicked: { root.editing = true; addressInput.text = root.location; addressInput.forceActiveFocus(); addressInput.selectAll() }
            }
            Row {
                visible: !root.editing
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(root.isTrash ? 0xF0A7A : root.location === root.home ? 0xF02DC : 0xF024B)
                    color: Theme.mutedForeground
                    font.family: Theme.fontIcon; font.pixelSize: 15
                }
                Breadcrumb {
                    anchors.verticalCenter: parent.verticalCenter
                    availableWidth: address.width - 8 - 15 - 6 - 8      // Rand, Icon, Abstand, Rand
                    items: root.crumbs
                    onNavigate: (p) => root.go(p)
                }
            }
            Input {
                id: addressInput
                visible: root.editing
                anchors.fill: parent
                fontSize: 13
                onAccepted: root.submitAddress(text)
                onEscapePressed: root.editing = false
                onActiveFocusChanged: if (!activeFocus) root.editing = false
            }
        }

        Input {
            id: searchInput
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, Math.min(260, root.width * 0.24))
            implicitHeight: 32
            fontSize: 13
            placeholder: root.isTrash ? tr.t("files.searchTrash") : tr.t("files.searchIn").arg(root.tabLabel(root.location))
            iconStart: String.fromCodePoint(0xF0349)
            onEscapePressed: text = ""
        }
    }

    // ---- Befehlsleiste ----
    Item {
        id: commandBar
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 48
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }

        readonly property var actions: [
            { a: "cut",    icon: 0xF0190, tip: tr.t("files.cutCtrlX"), label: tr.t("files.cut"), shortcut: tr.t("files.ctrlX") },
            { a: "copy",   icon: 0xF018F, tip: tr.t("files.copyCtrlC"), label: tr.t("files.copy"), shortcut: tr.t("files.ctrlC") },
            { a: "paste",  icon: 0xF0192, tip: tr.t("files.pasteCtrlV"), label: tr.t("files.paste"), shortcut: tr.t("files.ctrlV") },
            { a: "rename", icon: 0xF0455, tip: tr.t("files.renameF2"), label: I18n.t("common.rename"), shortcut: "F2" },
            { a: "trash",  icon: 0xF0A7A, tip: tr.t("files.moveToRecycleBinDel"), label: tr.t("files.moveToRecycleBin"), shortcut: tr.t("files.del") },
            { a: "undo",   icon: 0xF054C, tip: tr.t("files.undoCtrlZ"), label: tr.t("files.undo"), shortcut: tr.t("files.ctrlZ") }
        ]
        function actionEnabled(a) {
            return a === "paste" ? root.ops.canPaste
                 : a === "undo" ? root.ops.undoLabel !== ""
                 : a === "rename" ? (!!root.view && !!root.view.startRename && root.view.selectedPaths && root.view.selectedPaths.length === 1)
                 : !!(root.view && root.view.selectedPaths && root.view.selectedPaths.length > 0)
        }
        // Wird es eng, wandern die Aktionen von rechts nach links ins „⋯“-Menü (wie Windows 11)
        readonly property real room: rightTools.x - 16 - 12 - newBtn.width - 9      // Platz nach „Neu“ und Trenner
        readonly property int fitCount: room >= actions.length * 36 ? actions.length
                                      : Math.max(0, Math.floor((room - 36) / 36))
        readonly property bool narrow: width < 760

        // Ordner: Neu, Ausschneiden, Kopieren, Einfügen, Umbenennen, Löschen
        Row {
            visible: !root.isTrash
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Button {
                id: newBtn
                variant: "ghost"
                iconStart: String.fromCodePoint(0xF0415)
                iconEnd: String.fromCodePoint(0xF0140)
                text: tr.t("files.new")
                onClicked: {
                    const p = newBtn.mapToItem(root, 0, newBtn.height + 4)
                    root.showMenu([
                        { label: tr.t("files.folder"), icon: root.g(0xF0257), shortcut: tr.t("files.ctrlN"), action: "newFolder" },
                        { label: tr.t("files.textDocument"), icon: root.g(0xF0219), action: "newFile" }
                    ], p)
                }
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: Theme.border }
            Repeater {
                model: commandBar.actions
                Item {
                    required property var modelData
                    required property int index
                    visible: index < commandBar.fitCount
                    width: cb.width; height: cb.height
                    Button {
                        id: cb
                        variant: "ghost"
                        size: "icon"
                        iconStart: String.fromCodePoint(modelData.icon)
                        enabled: commandBar.actionEnabled(modelData.a)
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.doAction(modelData.a)
                    }
                    Tooltip { text: modelData.a === "undo" && root.ops.undoLabel ? tr.t("files.undoWhatShortcut").arg(root.ops.undoLabel) : modelData.tip; shown: cb.hovered }
                }
            }
            // Überlauf: ausgeblendete Aktionen
            Item {
                visible: commandBar.fitCount < commandBar.actions.length
                width: moreBtn.width; height: moreBtn.height
                Button {
                    id: moreBtn
                    variant: "ghost"
                    size: "icon"
                    iconStart: String.fromCodePoint(0xF01D8)
                    onClicked: root.showMenu(commandBar.actions.slice(commandBar.fitCount).map(x => ({
                        label: x.label, icon: root.g(x.icon), shortcut: x.shortcut, action: x.a,
                        disabled: !commandBar.actionEnabled(x.a) })), moreBtn.mapToItem(root, 0, moreBtn.height + 4))
                }
                Tooltip { text: tr.t("files.moreOptions"); shown: moreBtn.hovered }
            }
        }
        // Papierkorb
        Row {
            visible: root.isTrash
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Button {
                variant: "outline"
                iconStart: String.fromCodePoint(0xF099B)
                text: tr.t("files.restore")
                enabled: !!(root.view && root.view.selectedNames && root.view.selectedNames.length > 0)
                onClicked: root.doAction("restore")
            }
            Button {
                variant: "destructive"
                iconStart: String.fromCodePoint(0xF0A7A)
                text: tr.t("files.emptyRecycleBin")
                enabled: root.ops.trashItems.length > 0
                onClicked: root.doAction("emptyTrash")
            }
        }

        Row {
            id: rightTools
            visible: !root.isTrash
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Select {
                width: commandBar.narrow ? 150 : 190
                model: [{ value: "name", label: tr.t("files.sortByName") }, { value: "date", label: tr.t("files.sortByDateModified") },
                        { value: "type", label: tr.t("files.sortByType") }, { value: "size", label: tr.t("files.sortBySize") }]
                value: root.sortKey
                onActivated: (v) => root.doAction("sort", v)
            }
            Item {
                width: hiddenBtn.width; height: hiddenBtn.height
                Button {
                    id: hiddenBtn
                    variant: root.showHidden ? "secondary" : "ghost"
                    size: "icon"
                    iconStart: String.fromCodePoint(root.showHidden ? 0xF0208 : 0xF0209)
                    onClicked: root.showHidden = !root.showHidden
                }
                Tooltip { text: root.showHidden ? tr.t("files.hideHiddenItemsCtrlH") : tr.t("files.showHiddenItemsCtrlH"); shown: hiddenBtn.hovered }
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: Theme.border }
            Item {
                width: gridBtn.width; height: gridBtn.height
                Button {
                    id: gridBtn
                    variant: root.viewMode === "grid" ? "secondary" : "ghost"
                    size: "icon"
                    iconStart: String.fromCodePoint(0xF0570)
                    onClicked: root.viewMode = "grid"
                }
                Tooltip { text: tr.t("files.largeIcons"); shown: gridBtn.hovered }
            }
            Item {
                width: listBtn.width; height: listBtn.height
                Button {
                    id: listBtn
                    variant: root.viewMode === "list" ? "secondary" : "ghost"
                    size: "icon"
                    iconStart: String.fromCodePoint(0xF0279)
                    onClicked: root.viewMode = "list"
                }
                Tooltip { text: tr.t("files.details"); shown: listBtn.hovered }
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: Theme.border }
            Item {
                width: detailsBtn.width; height: detailsBtn.height
                Button {
                    id: detailsBtn
                    variant: root.showDetails ? "secondary" : "ghost"
                    size: "icon"
                    enabled: !root.compact
                    opacity: enabled ? 1 : 0.4
                    iconStart: String.fromCodePoint(0xF06FE)
                    onClicked: root.doAction("details")
                }
                Tooltip { text: tr.t("files.detailsPaneAltShiftP"); shown: detailsBtn.hovered }
            }
        }
    }

    // ===================== Seitenleiste =====================
    Rectangle {
        id: sidebar
        property string arrowScope: "sidebar"           // Pfeiltasten: Hoch/Runter bleibt in der Leiste
        property string arrowEnter: "active"            // Links aus dem Inhalt → aktiver Eintrag
        anchors { left: parent.left; top: commandBar.bottom; bottom: parent.bottom }
        width: root.collapsed ? 48 : 256
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        color: Theme.alpha(Theme.sidebar, Theme.glass)
        clip: true
        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.sidebarBorder }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: navCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: navCol
                    width: parent.width
                    spacing: 4

                    SidebarGroupLabel { width: parent.width; text: tr.t("files.quickAccess"); collapsed: root.collapsed }
                    Repeater {
                        model: root.places
                            ? [{ label: tr.t("files.home"), path: root.home, glyph: 0xF02DC }]
                                .concat(root.places.folders)
                                .concat(root.pinned.map(p => ({ label: p.split("/").pop() || p, path: p, glyph: 0xF0403, pinned: true })))
                            : []
                        Item {
                            id: navItem
                            required property var modelData
                            width: navCol.width
                            height: navBtn.height
                            SidebarMenuButton {
                                id: navBtn
                                width: parent.width
                                collapsed: root.collapsed
                                icon: String.fromCodePoint(navItem.modelData.glyph)
                                text: navItem.modelData.label
                                active: root.location === navItem.modelData.path
                                onClicked: root.go(navItem.modelData.path)
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                onClicked: (e) => e.button === Qt.MiddleButton ? root.newTab(navItem.modelData.path, false)
                                                                               : root.sidebarMenu(navItem.modelData.path, mapToItem(root, e.x, e.y))
                            }
                            SidebarDrop { target: navItem.modelData.path; onDropped: (paths, copy) => root.dropTo(paths, navItem.modelData.path, copy) }
                        }
                    }
                    Item {
                        id: trashItem
                        width: navCol.width
                        height: trashBtn.height
                        SidebarMenuButton {
                            id: trashBtn
                            width: parent.width
                            collapsed: root.collapsed
                            icon: String.fromCodePoint(0xF0A7A)
                            text: tr.t("files.recycleBin")
                            active: root.isTrash
                            onClicked: root.go("trash")
                        }
                        SidebarDrop { target: "trash"; onDropped: (paths, copy) => root.ops.trash(paths) }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: (e) => root.showMenu([
                                { label: I18n.t("common.open"), icon: root.g(0xF0770), action: "go", arg: "trash" },
                                { label: tr.t("files.emptyRecycleBin"), icon: root.g(0xF0A7A), action: "emptyTrash", variant: "destructive" }
                            ], mapToItem(root, e.x, e.y))
                        }
                    }

                    Item { width: 1; height: 4 }
                    SidebarGroupLabel { width: parent.width; text: tr.t("files.drives"); collapsed: root.collapsed }
                    Repeater {
                        model: root.places ? root.places.drives : []
                        Item {
                            id: driveItem
                            required property var modelData
                            width: navCol.width
                            height: btn.height
                            SidebarMenuButton {
                                id: btn
                                width: parent.width
                                collapsed: root.collapsed
                                icon: String.fromCodePoint(driveItem.modelData.removable ? 0xF02CB : 0xF02CA)
                                text: driveItem.modelData.label + (driveItem.modelData.mount === "/" ? " (/)" : "")
                                active: driveItem.modelData.mounted && root.location === driveItem.modelData.mount
                                onClicked: driveItem.modelData.mounted ? root.go(driveItem.modelData.mount) : root.places.mount(driveItem.modelData)
                            }
                            Button {
                                visible: !root.collapsed && driveItem.modelData.removable && driveItem.modelData.mounted
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                variant: "ghost"
                                size: "icon-xs"
                                iconStart: String.fromCodePoint(0xF01EA)
                                onClicked: root.doAction("eject", driveItem.modelData)
                            }
                            SidebarDrop {
                                visible: driveItem.modelData.mounted
                                target: driveItem.modelData.mount
                                onDropped: (paths, copy) => root.dropTo(paths, driveItem.modelData.mount, copy)
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                enabled: driveItem.modelData.mounted
                                onClicked: (e) => root.sidebarMenu(driveItem.modelData.mount, mapToItem(root, e.x, e.y),
                                    driveItem.modelData.removable ? { label: tr.t("files.eject"), icon: root.g(0xF01EA), action: "eject", arg: driveItem.modelData } : null)
                            }
                        }
                    }
                }
            }
        }
    }

    // ===================== Rechts =====================
    Item {
        id: main
        anchors { left: sidebar.right; right: parent.right; top: commandBar.bottom; bottom: parent.bottom }

        // ---- Inhalt ----
        Loader {
            id: pageLoader
            anchors { left: parent.left; right: detailsPane.visible ? detailsPane.left : parent.right; top: parent.top; bottom: statusBar.top }
            focus: true
            sourceComponent: root.isTrash ? trashComp : root.searching ? searchComp : folderComp
        }
        DetailsPane {
            id: detailsPane
            visible: root.showDetails && !root.isTrash
            anchors { right: parent.right; top: parent.top; bottom: statusBar.top }
            width: Math.min(320, Math.max(240, main.width * 0.28))
            script: root.ops.script
            ops: root.ops
            location: root.location
            paths: root.view && root.view.selectedPaths ? root.view.selectedPaths : []
            selectedSize: root.view && root.view.selectedSize ? root.view.selectedSize : 0
            dirs: root.view && root.view.selectedDirs ? root.view.selectedDirs : ({})
            onOpenRequested: (p) => root.doAction("open")
        }
        Component {
            id: searchComp
            SearchView {
                ops: root.ops
                path: root.location
                query: searchInput.text
                showHidden: root.showHidden
                cutPaths: root.ops.clip.mode === "cut" ? root.ops.clip.paths : []
                focus: true
                onOpenPath: (p, d) => root.openPath(p, d)
                onItemMenuRequested: (x, y) => root.itemMenu(x, y)
                onAction: (a) => root.doAction(a)
            }
        }
        Component {
            id: folderComp
            FolderView {
                path: root.location
                viewMode: root.viewMode
                sortKey: root.sortKey
                sortDesc: root.sortDesc
                showHidden: root.showHidden
                cutPaths: root.ops.clip.mode === "cut" ? root.ops.clip.paths : []
                focus: true
                Component.onCompleted: if (root.initialSelect) { selectWhenReady(root.initialSelect, false); root.initialSelect = "" }
                onSortChangeRequested: (k, d) => { root.sortKey = k; root.sortDesc = d }
                onOpenPath: (p, d) => root.openPath(p, d)
                onItemMenuRequested: (x, y) => root.itemMenu(x, y)
                onBackgroundMenuRequested: (x, y) => root.backgroundMenu(x, y)
                onRenameRequested: (p, n) => root.ops.rename(p, n)
                onAction: (a) => root.doAction(a)
                onDropRequested: (paths, dest, copy) => root.dropTo(paths, dest, copy)
                onOpenInNewTab: (p) => root.newTab(p, true)
            }
        }
        Component {
            id: trashComp
            TrashView {
                ops: root.ops
                search: searchInput.text
                focus: true
                onItemMenuRequested: (x, y) => root.trashItemMenu(x, y)
                onBackgroundMenuRequested: (x, y) => root.trashBackgroundMenu(x, y)
            }
        }

        // ---- Statuszeile ----
        Item {
            id: statusBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.border }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const v = root.view
                    if (!v) return ""
                    let t = I18n.tn("common.items", v.count).arg(v.count)
                    const n = root.isTrash ? v.selectedNames.length : v.selectedPaths.length
                    if (n > 0) t += "   |   " + tr.tn("files.selectedCount", n).arg(n)
                        + (!root.isTrash && v.selectedSize > 0 ? " (" + root.bytes(v.selectedSize) + ")" : "")
                    return t
                }
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.ops ? root.ops.busy : ""
                color: Theme.primary
                font.family: Theme.fontSans; font.pixelSize: 12
            }
        }
    }

    // Ziehen und Ablegen: Elemente nach dest kopieren oder verschieben
    function dropTo(paths, dest, copy) {
        if (!paths.length || !dest || dest === "trash") return
        ops.transfer(paths, dest, copy ? "copy" : "move")
    }

    function bytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0, v = b
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (v >= 100 || i === 0 ? Math.round(v) : I18n.formatNumber(v, 1)) + " " + u[i]
    }

    // ===================== Kontextmenü =====================
    function showMenu(entries, pos) {
        menu.model = entries
        menu.currentIndex = -1
        menu.openSubIndex = -1
        menu.submenuOnLeft = pos.x + menu.menuWidth * 2 > root.width
        menu.x = Math.max(8, Math.min(pos.x, root.width - menu.menuWidth - 8))
        menuLayer.visible = true
        menu.y = Math.max(8, Math.min(pos.y, root.height - menu.implicitHeight - 8))
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
            menuWidth: 250
            onTriggered: (entry) => {
                menuLayer.visible = false
                if (entry.action === "go") root.go(entry.arg)
                else root.doAction(entry.action, entry.arg)
                if (root.view) root.view.forceActiveFocus()
            }
            onCloseRequested: menuLayer.visible = false
            MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
        }
    }

    // ===================== Dialoge =====================
    // Konflikt beim Einfügen
    Dialog {
        id: conflictDialog
        property var names: []
        property string mode: "copy"
        property string dest: ""
        property var sources: []
        title: names.length === 1 ? tr.t("files.existsOne").arg(names[0]) : tr.t("files.existsMany").arg(names.length)
        description: tr.t("files.theDestinationAlreadyHasItems")
        Text {
            visible: conflictDialog.names.length > 1
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            text: conflictDialog.names.join(", ")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 12
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button { text: tr.t("files.keepBoth"); onClicked: { root.ops.doPaste(conflictDialog.mode, "keep", conflictDialog.dest, conflictDialog.sources); conflictDialog.close() } }
            Button { variant: "outline"; text: tr.t("files.replace"); onClicked: { root.ops.doPaste(conflictDialog.mode, "replace", conflictDialog.dest, conflictDialog.sources); conflictDialog.close() } }
            Button { variant: "ghost"; text: tr.t("files.skip"); onClicked: { root.ops.doPaste(conflictDialog.mode, "skip", conflictDialog.dest, conflictDialog.sources); conflictDialog.close() } }
        }
    }

    // „Wie möchtest du diese Datei öffnen?“ (wie Windows): passende Apps, „Weitere Apps“, Immer / Nur einmal
    Dialog {
        id: appChooser
        property string path: ""
        property string mime: ""
        property string selected: ""
        property bool showAll: false
        readonly property var fitting: root.apps ? root.apps.appsFor(mime) : []
        readonly property var others: root.apps && showAll
            ? root.apps.apps.filter(a => fitting.indexOf(a) < 0).sort((a, b) => a.name.localeCompare(b.name)) : []
        readonly property string ext: path.indexOf(".") > 0 ? path.split(".").pop().toLowerCase() : ""
        title: tr.t("files.howToOpen")
        description: path.split("/").pop()

        function run(always) {
            const a = root.apps ? root.apps.appById(selected) : null
            if (!a) return
            if (always) root.apps.setDefaultMime(mime, a.id)
            root.ops.openWith(a, [path])
            close()
        }

        Flickable {
            width: parent.width
            height: Math.min(contentHeight, 320)
            contentHeight: chooserCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: chooserCol
                width: parent.width
                spacing: 2
                Repeater {
                    model: appChooser.fitting.concat(appChooser.others)
                    delegate: Rectangle {
                        id: appRow
                        required property var modelData
                        required property int index
                        readonly property bool active: appChooser.selected === modelData.id
                        width: chooserCol.width
                        height: 40
                        radius: Theme.radiusMd
                        color: active ? Theme.accent : "transparent"
                        HoverLayer { radius: parent.radius; shown: rowMouse.containsMouse && !appRow.active }
                        border.width: activeFocus ? 2 : 0
                        border.color: Theme.ring
                        activeFocusOnTab: true
                        readonly property bool ownFocusRing: true
                        signal clicked()
                        onClicked: appChooser.selected = modelData.id
                        Keys.onReturnPressed: appChooser.run(false)
                        Keys.onSpacePressed: appChooser.selected = modelData.id
                        Keys.onPressed: (e) => FocusNav.key(appRow, e)
                        onActiveFocusChanged: if (activeFocus) appChooser.selected = modelData.id
                        Image {
                            id: appIcon
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24
                            source: root.apps ? root.apps.iconSource(appRow.modelData.icon) : ""
                            sourceSize: Qt.size(48, 48)
                            asynchronous: true
                            Text {                       // ohne Icon: allgemeines App-Symbol
                                anchors.centerIn: parent
                                visible: appIcon.status !== Image.Ready
                                text: String.fromCodePoint(0xF003B)
                                color: Theme.mutedForeground
                                font.family: Theme.fontIcon; font.pixelSize: 20
                            }
                        }
                        Text {
                            anchors.left: appIcon.right; anchors.leftMargin: 12
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: appRow.modelData.name
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 14
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appChooser.selected = appRow.modelData.id
                            onDoubleClicked: { appChooser.selected = appRow.modelData.id; appChooser.run(false) }
                        }
                    }
                }
                Button {
                    visible: !appChooser.showAll
                    variant: "link"
                    size: "sm"
                    text: tr.t("files.moreApps")
                    onClicked: appChooser.showAll = true
                }
            }
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: tr.t("files.always")
                enabled: appChooser.selected !== ""
                onClicked: appChooser.run(true)
            }
            Button {
                variant: "outline"
                text: tr.t("files.justOnce")
                enabled: appChooser.selected !== ""
                onClicked: appChooser.run(false)
            }
        }
    }

    // Endgültig löschen (auch aus dem Papierkorb)
    Dialog {
        id: deleteDialog
        property var paths: []
        property var trashNames: []
        readonly property int n: paths.length || trashNames.length
        title: n === 1 ? tr.t("files.deleteQuestion") : tr.t("files.deleteManyQuestion").arg(n)
        description: n === 1 ? tr.t("files.deleteOneDesc").arg(paths.length ? paths[0].split("/").pop() : trashNames[0])
                     : tr.t("files.deleteManyDesc")
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                variant: "destructive"
                text: tr.t("files.deletePermanently")
                onClicked: {
                    if (deleteDialog.paths.length) root.ops.deleteForever(deleteDialog.paths)
                    else root.ops.deleteFromTrash(deleteDialog.trashNames)
                    deleteDialog.paths = []; deleteDialog.trashNames = []
                    deleteDialog.close()
                }
            }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: deleteDialog.close() }
        }
    }

    Dialog {
        id: emptyDialog
        title: tr.t("files.emptyTheRecycleBin")
        description: tr.tn("files.emptyTrashDesc", root.ops.trashItems.length).arg(root.ops.trashItems.length)
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button { variant: "destructive"; text: tr.t("files.emptyRecycleBin"); onClicked: { root.ops.emptyTrash(); emptyDialog.close() } }
            Button { variant: "ghost"; text: I18n.t("common.cancel"); onClicked: emptyDialog.close() }
        }
    }

    // Eigenschaften
    function showProperties(paths) {
        propsDialog.paths = paths
        propsDialog.info = null
        propsDialog.open()
        ops.properties(paths, (r) => propsDialog.info = r)
    }
    Dialog {
        id: propsDialog
        property var paths: []
        property var info: null
        readonly property var first: info && info.items.length ? info.items[0] : null
        readonly property bool single: paths.length === 1
        readonly property bool isDir: !!first && first.type === "directory"
        title: single ? (paths[0].split("/").pop() || "/") : I18n.tn("common.items", paths.length).arg(paths.length)
        description: tr.t("files.properties")

        function fmt(ms) { return ms > 0 ? new Date(ms).toLocaleString(I18n.locale, tr.t("files.dateTimeFormat")) : "–" }
        readonly property var rows: {
            if (!info) return [["", tr.t("files.determining")]]
            const r = []
            if (single && first) {
                r.push([tr.t("files.type"), isDir ? tr.t("type.folder") : (info.mime || first.type)])
                r.push([tr.t("files.location"), root.parentOf(paths[0])])
            } else r.push([tr.t("files.location"), root.parentOf(paths[0])])
            r.push([tr.t("files.size"), tr.t("files.sizeBytes").arg(root.bytes(info.total)).arg(info.total.toLocaleString(I18n.locale, "f", 0))])
            if (isDir || !single) r.push([tr.t("files.contents"), tr.t("files.filesFolders").arg(info.files).arg(info.dirs)])
            if (single && first) {
                r.push([tr.t("files.created"), fmt(first.created)])
                r.push([tr.t("files.modified"), fmt(first.modified)])
                r.push([tr.t("files.accessed"), fmt(first.accessed)])
                r.push([tr.t("files.permissions"), first.mode])
                r.push([tr.t("files.owner"), tr.t("files.ownerGroup").arg(first.owner).arg(first.group)])
            }
            return r
        }

        Row {
            width: parent.width
            spacing: 14
            visible: propsDialog.single
            FileIcon {
                size: 48
                name: propsDialog.paths.length ? propsDialog.paths[0].split("/").pop() : ""
                path: propsDialog.paths.length ? propsDialog.paths[0] : ""
                isDir: propsDialog.isDir
                thumbnail: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 62
                elide: Text.ElideMiddle
                text: propsDialog.paths.length ? propsDialog.paths[0] : ""
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 12
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.border }
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 16
            rowSpacing: 8
            Repeater {
                model: propsDialog.rows.reduce((a, r) => a.concat(r), [])
                Text {
                    required property var modelData
                    required property int index
                    width: index % 2 === 0 ? 110 : propsDialog.width - 48 - 110 - 16
                    wrapMode: Text.WrapAnywhere
                    text: modelData
                    color: index % 2 === 0 ? Theme.mutedForeground : Theme.foreground
                    font.family: Theme.fontSans; font.pixelSize: 13
                }
            }
        }
        Row {
            width: parent.width
            layoutDirection: Qt.RightToLeft
            Button { text: "OK"; onClicked: propsDialog.close() }
        }
    }

    // ===================== Fortschritt (Kopieren großer Datenmengen) =====================
    // erscheint erst, wenn das Kopieren länger als einen Moment dauert
    property bool progressShown: false
    Timer { id: progressDelay; interval: 700; onTriggered: root.progressShown = !!root.ops.progress }
    Connections {
        target: root.ops
        function onProgressChanged() {
            if (!root.ops.progress) { progressDelay.stop(); root.progressShown = false }
            else if (!root.progressShown && !progressDelay.running) progressDelay.start()
        }
    }
    Rectangle {
        id: progressCard
        readonly property var p: root.ops.progress
        readonly property real frac: p && p.total > 0 ? Math.min(1, p.done / p.total) : 0
        visible: root.progressShown && !!p
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.bottomMargin: 42
        width: 360
        height: progCol.implicitHeight + 32
        radius: Theme.radiusLg
        color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
        border.width: 1
        border.color: Theme.border
        z: 55
        Column {
            id: progCol
            x: 16; y: 16
            width: parent.width - 32
            spacing: 10
            Item {
                width: parent.width
                height: progTitle.implicitHeight
                Text {
                    id: progTitle
                    width: parent.width - 40
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: progressCard.p ? progressCard.p.title : ""
                    color: Theme.foreground
                    font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                }
                Button {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: -6
                    variant: "ghost"; size: "icon-sm"
                    iconStart: String.fromCodePoint(0xF0156)
                    onClicked: root.ops.cancel()
                }
            }
            Text {
                text: tr.t("files.percentDone").arg(Math.round(progressCard.frac * 100))
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 12
            }
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.muted
                Rectangle {
                    width: parent.width * progressCard.frac
                    height: parent.height
                    radius: 3
                    color: Theme.primary
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Item {
                width: parent.width
                height: progLeft.implicitHeight
                Text {
                    id: progLeft
                    width: parent.width * 0.6
                    elide: Text.ElideMiddle
                    text: progressCard.p && progressCard.p.current ? progressCard.p.current : ""
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    text: {
                        const p = progressCard.p
                        if (!p) return ""
                        let t = tr.t("files.bytesOf").arg(root.bytes(p.done)).arg(root.bytes(p.total))
                        if (p.speed > 0) {
                            const left = Math.max(0, (p.total - p.done) / p.speed)
                            t += "  ·  " + root.bytes(p.speed) + "/s  ·  " + (left < 60 ? tr.t("files.lessThanMinute") : I18n.t("common.durationMinutes").arg(Math.round(left / 60)))
                        }
                        return t
                    }
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    // ===================== Hinweis =====================
    function toast(t) { toastBox.text = t; toastBox.opacity = 1; toastTimer.restart() }
    Rectangle {
        id: toastBox
        property string text: ""
        visible: opacity > 0
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        anchors.horizontalCenter: main.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        width: Math.min(toastText.implicitWidth + 32, root.width - 64)
        height: 40
        radius: Theme.radiusLg
        color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
        border.width: 1
        border.color: Theme.border
        z: 60
        Text { id: toastText; anchors.centerIn: parent; width: parent.width - 24; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: toastBox.text; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 13 }
        Timer { id: toastTimer; interval: 4000; onTriggered: toastBox.opacity = 0 }
    }

    Connections {
        target: root.places
        function onMounted(path) { root.go(path) }
        function onErrorChanged() { if (root.places.error) root.toast(root.places.error) }
    }
    Connections {
        target: root.ops
        function onErrorChanged() { if (root.ops.error) root.toast(root.ops.error) }
        function onCreated(path) { if (root.view && root.view.selectWhenReady) root.view.selectWhenReady(path, true) }
        function onRenamed(path) { if (root.view && root.view.selectWhenReady) root.view.selectWhenReady(path, false) }
        function onRenamedQuiet(path) { if (root.view && root.view.selectWhenReady) root.view.selectWhenReady(path, false) }
        function onUndone(label) { root.toast(tr.t("files.undoWhat").arg(label)) }
        function onConflict(names, mode, dest, sources) {
            conflictDialog.names = names; conflictDialog.mode = mode; conflictDialog.dest = dest; conflictDialog.sources = sources
            conflictDialog.open()
        }
    }
}
