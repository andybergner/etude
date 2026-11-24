import QtQuick

// Eingabefeld (shadcn: Input): h-9, rounded-md, border-input, dark:bg-input/30,
// Fokus = border-ring + 3px ring/50. Optional ein Icon links.
// Tab / Shift+Tab springt zum nächsten / vorigen Bedienelement (tabNavigation: false schaltet das
// ab, z. B. wenn Tab in einer Liste blättern soll – die Signale tabPressed/backtabPressed kommen immer).
// Hoch/Runter wandert wie in Listen zum Element darüber/darunter (siehe FocusNav.js).
//   Input { placeholder: "Suchen"; iconStart: "…" }
FocusScope {
    id: root

    property alias text: field.text
    property alias echoMode: field.echoMode
    property string placeholder: ""
    property string iconStart: ""
    property real radius: Theme.radiusMd
    property int fontSize: 14
    property bool tabNavigation: true

    signal accepted()
    signal escapePressed()
    signal downPressed()
    signal upPressed()
    signal tabPressed()
    signal backtabPressed()

    implicitWidth: 240
    implicitHeight: 36
    activeFocusOnTab: true
    readonly property bool ownFocusRing: true

    // zum nächsten/vorigen Element in der Tab-Reihenfolge
    property bool _tabbed: false
    function focusNext(forward) {
        const n = root.nextItemInFocusChain(forward)
        if (!n || n === root) return
        if (n._tabbed !== undefined) n._tabbed = true      // nächstes Eingabefeld: Text markieren
        n.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }

    function clear() { field.text = "" }
    function appendText(t) { field.text += t; field.cursorPosition = field.text.length; field.deselect() }
    function selectAll() { field.selectAll() }
    function select(a, b) { field.select(a, b) }

    // Fokus-Ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: root.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(Theme.ring, 0.5)
        visible: field.activeFocus
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.dark ? Theme.alpha(Theme.input, Theme.input.a * 0.3) : "transparent"
        border.width: 1
        border.color: field.activeFocus ? Theme.ring : Theme.input
        Behavior on border.color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
    }

    Text {
        id: icon
        visible: root.iconStart !== ""
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.iconStart
        color: Theme.mutedForeground
        font.family: Theme.fontIcon
        font.pixelSize: 16
    }

    TextInput {
        id: field
        focus: true
        anchors.left: icon.visible ? icon.right : parent.left
        anchors.leftMargin: icon.visible ? 8 : 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.foreground
        selectionColor: Theme.alpha(Theme.ring, 0.5)
        selectedTextColor: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: root.fontSize
        clip: true
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onEscapePressed: root.escapePressed()
        // Hoch/Runter: Signal + (mit tabNavigation) Pfeil-Navigation im Bereich (FocusNav)
        Keys.onDownPressed: (e) => { root.downPressed(); e.accepted = !root.tabNavigation || FocusNav.move(root, "down") }
        Keys.onUpPressed: (e) => { root.upPressed(); e.accepted = !root.tabNavigation || FocusNav.move(root, "up") }
        Keys.onTabPressed: { root.tabPressed(); if (root.tabNavigation) root.focusNext(true) }
        Keys.onBacktabPressed: { root.backtabPressed(); if (root.tabNavigation) root.focusNext(false) }
        // per Tab angesprungen: Text markieren (wie Windows) – beim Klicken nicht
        onActiveFocusChanged: { if (activeFocus && root._tabbed) selectAll(); root._tabbed = false }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text === ""
            text: root.placeholder
            color: Theme.mutedForeground
            font: field.font
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: (e) => { field.forceActiveFocus(); e.accepted = false }
    }
}
