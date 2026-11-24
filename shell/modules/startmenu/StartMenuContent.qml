import QtQuick
import QtQuick.Layouts
import Etude.Ui
import "PowerEntries.js" as Power
import "AppSearch.js" as AppSearch

// Startmenü – reines QtQuick, ohne Quickshell (einzeln testbar).
// Aufbau: Suchfeld oben, alle Apps als Raster (wie Launchpad), Fußleiste unten.
Surface {
    id: root
    property Translations tr: Translations { domain: "startmenu" }   // Texte dieses Moduls

    property string userName: ""
    property alias searchText: search.text

    // Daten (kommen aus services/Apps.qml)
    property var apps: []                    // [{ id, name, generic, keywords, icon }]

    readonly property bool searching: search.text.trim() !== ""
    readonly property var shown: searching ? AppSearch.search(apps, search.text, 200) : apps
    property int selected: -1                // markierte App (-1 = keine)
    onShownChanged: selected = searching && shown.length > 0 ? 0 : -1

    signal launch(string id)
    signal powerAction(var entry)            // Eintrag im Ein/Aus-Menü gewählt
    signal userClicked()
    signal closeRequested()

    width: 640
    height: 680

    // Abstände wie bei Windows 11: viel Luft links/rechts
    readonly property int pad: 32
    radius: Theme.radiusXl
    padding: 0

    property bool powerMenuOpen: false

    // Position erst beim Öffnen berechnen (dann ist das Layout fertig)
    onPowerMenuOpenChanged: {
        if (!powerMenuOpen) return
        const p = powerBtn.mapToItem(powerMenu.parent, 0, 0)
        powerMenu.anchorRight = p.x + powerBtn.width
        powerMenu.anchorTop = p.y
        powerMenu.currentIndex = powerBtn.visualFocus ? 0 : -1    // per Tastatur geöffnet: ersten Eintrag markieren
        powerMenu.forceActiveFocus()
    }

    function focusSearch() { search.forceActiveFocus() }
    function reset() {
        search.clear()
        selected = -1
        powerMenuOpen = false
        grid.positionViewAtBeginning()
    }
    // ↑/↓ springt eine Reihe, Tab/Shift+Tab eine App weiter
    function moveSelection(step) {
        if (shown.length === 0) return
        selected = selected < 0 ? 0 : Math.max(0, Math.min(shown.length - 1, selected + step))
        grid.positionViewAtIndex(selected, GridView.Contain)
    }

    function closePowerMenu() { powerMenuOpen = false; focusSearch() }
    // Esc/Links im Ein/Aus-Menü: zurück auf den Power-Button (wie Windows)
    function closePowerMenuToButton() { powerMenuOpen = false; powerBtn.forceActiveFocus(Qt.TabFocusReason) }

    // ---- Tastatur wie im Windows-Startmenü ----
    // Tab/Shift+Tab: Suche → App-Raster → Benutzer → Ein/Aus (und zurück)
    // Pfeile: im Raster von App zu App, sonst zum Nachbarn (FocusRoot), Enter: starten/öffnen
    // Tippen irgendwo: springt in die Suche; Esc: schließt (in der Suche erst leeren)
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) { root.powerMenuOpen ? root.closePowerMenuToButton() : root.closeRequested(); e.accepted = true; return }
        const typed = e.text.length === 1 && e.text >= " " && e.text !== "\x7f"
        if (typed && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && !search.activeFocus && !root.powerMenuOpen) {
            search.forceActiveFocus()
            search.appendText(e.text)
            e.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1                  // Rand der Surface sichtbar lassen
        spacing: 0

        // ===== oben: Suche (abgesetzt wie die Fußleiste) =====
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            color: Theme.alpha(Theme.muted, 0.5)
            topLeftRadius: root.radius - 1
            topRightRadius: root.radius - 1

            Rectangle {                              // Trennlinie unten
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Theme.border
            }

            Input {
                id: search
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: root.pad; anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                // shadcn-Standard: h-9, rounded-md, px-3
                iconStart: String.fromCodePoint(0xF0349)   // md-magnify
                placeholder: root.tr.t("startmenu.searchApps")
                onEscapePressed: root.searching ? search.clear() : root.closeRequested()
                // Runter/Tab: ins App-Raster (Pfeil-Navigation bzw. Tab-Kette), Enter startet den markierten Treffer
                onAccepted: if (root.selected >= 0 && root.shown[root.selected]) root.launch(root.shown[root.selected].id)
            }
        }

        // ===== Mitte: alle installierten Apps als Raster (wie Launchpad) =====
        // Ohne Suche alphabetisch, mit Suche gefiltert und nach Treffer sortiert.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.leftMargin: root.pad - 8
                anchors.rightMargin: root.pad - 8
                topMargin: 16
                bottomMargin: 16
                cellWidth: Math.floor(width / 7)
                cellHeight: 90
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.shown
                currentIndex: root.selected
                // eine Tab-Station (wie Windows), Pfeile wandern von App zu App, am Rand weiter zum Nachbarn
                activeFocusOnTab: root.shown.length > 0
                keyNavigationEnabled: false
                onActiveFocusChanged: if (activeFocus && root.selected < 0 && root.shown.length > 0) root.selected = 0
                readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
                Keys.onPressed: (e) => {
                    if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier)) return
                    const n = root.shown.length, i = root.selected, c = columns
                    let t = -1
                    if (e.key === Qt.Key_Right && i + 1 < n && (i + 1) % c !== 0) t = i + 1
                    else if (e.key === Qt.Key_Left && i > 0 && i % c !== 0) t = i - 1
                    else if (e.key === Qt.Key_Down && i + c < n) t = i + c
                    else if (e.key === Qt.Key_Down && Math.floor(i / c) < Math.floor((n - 1) / c)) t = n - 1   // letzte, kürzere Reihe
                    else if (e.key === Qt.Key_Up && i - c >= 0) t = i - c
                    else if (e.key === Qt.Key_Home) t = 0
                    else if (e.key === Qt.Key_End) t = n - 1
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) && root.shown[i]) {
                        root.launch(root.shown[i].id); e.accepted = true; return
                    }
                    if (t < 0) return                        // Rand: weiter zum Nachbarn (FocusRoot)
                    root.selected = t
                    grid.positionViewAtIndex(t, GridView.Contain)
                    e.accepted = true
                }

                delegate: AppTile {
                    id: tile
                    required property var modelData
                    required property int index
                    app: modelData
                    width: grid.cellWidth
                    height: grid.cellHeight
                    selected: index === root.selected
                    keyboardFocus: selected && grid.activeFocus
                    onClicked: root.launch(modelData.id)
                }

                // Scrollbalken, nur beim Scrollen sichtbar
                Rectangle {
                    visible: grid.contentHeight > grid.height
                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    width: 4
                    radius: 2
                    y: grid.visibleArea.yPosition * grid.height
                    height: grid.visibleArea.heightRatio * grid.height
                    color: Theme.mutedForeground
                    opacity: grid.moving ? 0.6 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }

            Text {
                visible: root.shown.length === 0
                anchors.centerIn: parent
                text: root.searching ? root.tr.t("startmenu.noResults").arg(search.text.trim()) : root.tr.t("startmenu.noApps")
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 13
            }
        }

        // ===== unten: Benutzer + Ein/Aus =====
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            color: Theme.alpha(Theme.muted, 0.5)
            bottomLeftRadius: root.radius - 1
            bottomRightRadius: root.radius - 1

            Rectangle {                              // Trennlinie oben
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.pad
                anchors.rightMargin: root.pad - 6

                // Benutzer (per Tab/Pfeil erreichbar, Enter öffnet – Ring und Enter macht FocusRoot)
                Rectangle {
                    id: userBtn
                    activeFocusOnTab: true
                    signal clicked()
                    onClicked: root.userClicked()
                    implicitWidth: userRow.implicitWidth + 12
                    implicitHeight: 36
                    Layout.leftMargin: -6                    // Avatar bündig mit dem Suchfeld
                    radius: Theme.radiusMd
                    color: userMouse.containsMouse ? Theme.accent : "transparent"
                    Row {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 8
                        Avatar { name: root.userName; size: 28; radius: Theme.radiusMd; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.userName
                            color: Theme.foreground
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea { id: userMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: userBtn.clicked() }
                }

                Item { Layout.fillWidth: true }

                // Ein/Aus
                Button {
                    id: powerBtn
                    variant: "ghost"
                    size: "icon-lg"
                    expanded: root.powerMenuOpen
                    iconStart: String.fromCodePoint(0xF0425)   // md-power
                    onClicked: root.powerMenuOpen ? root.closePowerMenu() : (root.powerMenuOpen = true)
                }
            }
        }
    }

    // ===== Ein/Aus-Menü über dem Power-Button =====
    // Klick irgendwo anders ins Startmenü schließt nur dieses Menü
    MouseArea {
        anchors.fill: parent
        visible: root.powerMenuOpen
        onPressed: root.closePowerMenu()
    }

    ContextMenu {
        id: powerMenu
        visible: root.powerMenuOpen
        model: Power.entries(root.tr)
        menuWidth: 200
        width: implicitWidth
        // Ecke des Power-Buttons; Größe des Menüs steht erst fest, wenn es sichtbar ist
        property real anchorRight: 0
        property real anchorTop: 0
        x: anchorRight - implicitWidth          // rechtsbündig zum Button
        y: anchorTop - implicitHeight - 6       // darüber
        onTriggered: (entry) => { root.powerMenuOpen = false; root.powerAction(entry) }
        onCloseRequested: root.closePowerMenuToButton()
    }

}
