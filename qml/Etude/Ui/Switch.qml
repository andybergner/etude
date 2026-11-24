import QtQuick

// Schalter (shadcn: Switch): 32×18, an = bg-primary, aus = bg-input
Item {
    id: root
    property bool checked: false
    property bool enabled_: true
    signal toggled()

    implicitWidth: 34
    implicitHeight: 20
    opacity: enabled_ ? 1 : 0.5

    // Tastatur: Tab erreicht den Schalter, Leertaste/Enter schaltet um
    activeFocusOnTab: enabled_
    Keys.onSpacePressed: if (enabled_) toggled()
    Keys.onReturnPressed: if (enabled_) toggled()
    Keys.onEnterPressed: if (enabled_) toggled()
    Keys.onPressed: (e) => FocusNav.key(root, e)        // Pfeiltasten: zum Nachbarn
    readonly property bool ownFocusRing: true           // FocusRoot zeichnet keinen zusätzlichen Ring

    // Fokus-Ring bei Tastaturbedienung (Tab / Shift+Tab)
    readonly property bool keyboardFocus: activeFocus   // Klicks geben keinen Fokus – Fokus heißt hier Tastatur
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2 + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(Theme.ring, 0.5)
        visible: root.keyboardFocus
        z: 10
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : (Theme.dark ? Theme.alpha(Theme.input, Math.min(1, Theme.input.a * 5)) : Theme.input)
        Behavior on color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
    }
    Rectangle {
        width: 16; height: 16; radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2
        color: Theme.dark ? (root.checked ? Theme.primaryForeground : Theme.foreground) : Theme.background
        Behavior on x { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled_
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
