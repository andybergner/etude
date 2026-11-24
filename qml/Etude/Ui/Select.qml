import QtQuick
import QtQuick.Templates as T

// shadcn: Select – Auslöser mit aktuellem Wert und Pfeil, darunter eine Liste.
// Bei vielen Einträgen mit Suchfeld (z. B. Zeitzonen).
//   Select { model: [{ value: "de", label: "Deutsch" }, …]; value: "de"
//            onActivated: (v) => … }
// Einträge dürfen auch einfache Strings sein.
Item {
    id: root

    property var model: []
    property string value: ""
    property string placeholder: I18n.t("common.select")
    property bool searchable: items.length > 12
    property bool enabled_: true
    signal activated(string value)

    implicitWidth: 240
    implicitHeight: 32

    readonly property var items: model.map(m => typeof m === "string" ? { value: m, label: m } : m)
    readonly property string currentLabel: {
        const it = items.find(i => i.value === value)
        return it ? it.label : (value || "")
    }

    // ---- Tastatur: Tab erreicht die Auswahl; Leertaste/Enter/Alt+Runter öffnen die Liste,
    // dort Pfeile wählen, Enter übernimmt, Esc schließt – der Fokus kommt danach zurück ----
    activeFocusOnTab: enabled_
    readonly property bool keyboardFocus: activeFocus   // Klicks geben keinen Fokus – Fokus heißt hier Tastatur
    property bool _byKeyboard: false
    function openByKeyboard() { if (!enabled_) return; _byKeyboard = true; popup.open() }
    function choose(i) {
        if (i < 0 || i >= list.count) return
        activated(list.model[i].value)
        popup.close()
    }
    Keys.onSpacePressed: openByKeyboard()
    Keys.onReturnPressed: openByKeyboard()
    Keys.onEnterPressed: openByKeyboard()
    // Alt+Runter öffnet (wie Windows); Hoch/Runter allein bleibt für die Navigation
    Keys.onDownPressed: (e) => { if (e.modifiers & Qt.AltModifier) openByKeyboard(); else e.accepted = false }
    Keys.onPressed: (e) => FocusNav.key(root, e)        // Pfeiltasten: zum Nachbarn
    readonly property bool ownFocusRing: true           // FocusRoot zeichnet keinen zusätzlichen Ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: Theme.radiusMd + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(Theme.ring, 0.5)
        visible: root.keyboardFocus && !popup.opened
        z: 10
    }

    // ---- Auslöser ----
    Rectangle {
        id: trigger
        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.input, Theme.dark ? Theme.input.a * 0.3 : 0)
        border.width: 1
        border.color: popup.opened ? Theme.ring : Theme.input
        opacity: root.enabled_ ? 1 : 0.5
        HoverLayer { shown: mouse.containsMouse && root.enabled_ }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel || root.placeholder
            elide: Text.ElideRight
            color: root.currentLabel ? Theme.foreground : Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0140)               // md-chevron_down
            color: Theme.mutedForeground
            font.family: Theme.fontIcon
            font.pixelSize: 16
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled_
            cursorShape: Qt.PointingHandCursor
            onClicked: { root._byKeyboard = false; popup.opened ? popup.close() : popup.open() }
        }
    }

    // ---- Liste ----
    T.Popup {
        id: popup
        y: root.height + 4
        width: Math.max(root.width, 220)
        height: Math.min(contentCol.implicitHeight + 8, 340)
        padding: 4
        margins: 8
        focus: true
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

        onOpened: {
            filter.text = ""
            const i = list.model.findIndex(it => it.value === root.value)
            list.currentIndex = i >= 0 ? i : 0
            if (i >= 0) list.positionViewAtIndex(i, ListView.Center)
            if (root.searchable) filter.forceActiveFocus()
            else list.forceActiveFocus()
        }
        onClosed: if (root._byKeyboard) { root._byKeyboard = false; root.forceActiveFocus() }

        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.popover
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Column {
            id: contentCol
            spacing: 4

            Input {
                id: filter
                visible: root.searchable
                width: parent.width
                placeholder: I18n.t("common.searchEllipsis")
                iconStart: String.fromCodePoint(0xF0349)
                tabNavigation: false
                onAccepted: root.choose(list.currentIndex >= 0 ? list.currentIndex : 0)
                onEscapePressed: popup.close()
                onDownPressed: { root._byKeyboard = true; list.incrementCurrentIndex() }
                onUpPressed: { root._byKeyboard = true; list.decrementCurrentIndex() }
                onTextChanged: list.currentIndex = 0
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, 340 - 8 - (filter.visible ? filter.height + 4 : 0))
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: false
                highlightMoveDuration: 0
                Keys.onReturnPressed: root.choose(currentIndex)
                Keys.onEnterPressed: root.choose(currentIndex)
                Keys.onSpacePressed: root.choose(currentIndex)
                Keys.onEscapePressed: popup.close()
                Keys.onTabPressed: popup.close()
                model: {
                    const q = filter.text.trim().toLowerCase()
                    return q ? root.items.filter(i => (i.label + " " + i.value).toLowerCase().indexOf(q) >= 0) : root.items
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    width: list.width
                    height: 32
                    readonly property bool selected: modelData.value === root.value

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSm
                        color: "transparent"
                        HoverLayer { shown: rowMouse.containsMouse || (root._byKeyboard && row.ListView.isCurrentItem) }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: check.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        elide: Text.ElideRight
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                    }
                    Text {
                        id: check
                        visible: row.selected
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(0xF012C)
                        color: Theme.foreground
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.activated(row.modelData.value); popup.close() }
                    }
                }
            }

            Text {
                visible: list.count === 0
                padding: 8
                text: I18n.t("common.noResults")
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 12
            }
        }
    }
}
