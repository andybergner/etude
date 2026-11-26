import QtQuick

// Schieberegler (shadcn: Slider): Spur h-1.5 bg-muted, Bereich bg-primary,
// Griff size-4 rund, bg-background mit Rand in primary, Fokus-Ring beim Ziehen.
Item {
    id: root

    property real value: 0.5          // 0..1
    property real step: 0.01
    property bool enabled_: true
    // Mausrad: "auto" (Standard) – frei stehend ändert das Rad den Wert, in einer scrollbaren Seite
    // nur, nachdem der Regler angeklickt wurde (bis die Maus ihn verlässt) oder per Tastatur den
    // Fokus hat; sonst scrollt die Seite weiter. "always" / "never" erzwingen das eine oder andere.
    property string wheel: "auto"

    signal moved(real value)          // beim Ziehen/Klicken (nicht bei Änderung von außen)

    implicitWidth: 200
    implicitHeight: 20
    opacity: enabled_ ? 1 : 0.5

    // Tastatur: Tab erreicht den Regler, Links/Rechts ändern in 5-%-Schritten (Hoch/Runter bleibt für die Navigation), Pos1/Ende springen an den Rand
    activeFocusOnTab: enabled_
    readonly property bool ownFocusRing: true           // FocusRoot zeichnet keinen zusätzlichen Ring
    // Eigene Änderungen kurz festhalten: Lautstärke/Helligkeit melden ihren Wert verzögert zurück –
    // ohne das springt der Regler zwischendurch auf den alten Wert (z. B. von 100 % auf 95 %) und der
    // nächste Schritt rechnet vom falschen Wert aus.
    property real held: 0
    property bool holding: false
    readonly property real shown: holding ? held : value
    Timer { id: holdTimer; interval: 800; onTriggered: root.holding = false }
    function userSet(v) {
        v = Math.max(0, Math.min(1, Math.round(v * 1000) / 1000))
        held = v; holding = true; holdTimer.restart()
        moved(v)
    }
    // Schritt von 5 %, immer auf das 5-%-Raster (97 % + Schritt = 100 %, nicht 102 % → 100 % → 95 %)
    function nudge(d) { userSet(Math.round((shown + d) / 0.05) * 0.05) }
    Keys.onLeftPressed: nudge(-0.05)
    Keys.onRightPressed: nudge(0.05)
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Home) { userSet(0); e.accepted = true }
        else if (e.key === Qt.Key_End) { userSet(1); e.accepted = true }
        else FocusNav.key(root, e)                       // Hoch/Runter: zum Nachbarn
    }
    readonly property bool keyboardFocus: activeFocus   // Klicks geben keinen Fokus – Fokus heißt hier Tastatur

    // Liegt der Regler in einer Seite, die gerade scrollen kann?
    function inScrollable() {
        for (let p = parent; p; p = p.parent) {
            if (p.flickableDirection !== undefined && p.contentHeight !== undefined
                    && (p.contentHeight > p.height + 1 || p.contentWidth > p.width + 1)) return true
        }
        return false
    }
    property bool engaged: false      // angeklickt, solange die Maus darüber bleibt
    function wheelWanted() {
        if (wheel === "never") return false
        if (wheel === "always") return true
        return engaged || activeFocus || !inScrollable()
    }

    readonly property real knob: 16
    readonly property real pos: Math.max(0, Math.min(1, shown)) * (width - knob)

    Rectangle {                       // Spur
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6; radius: 3
        color: Theme.muted
        Rectangle {                   // gefüllter Bereich
            width: root.pos + root.knob / 2
            height: parent.height; radius: 3
            color: Theme.primary
        }
    }

    Rectangle {                       // Fokus-/Drag-Ring
        visible: mouse.pressed || mouse.containsMouse || root.keyboardFocus
        x: root.pos - 4; anchors.verticalCenter: parent.verticalCenter
        width: root.knob + 8; height: width; radius: width / 2
        color: Theme.alpha(Theme.ring, root.keyboardFocus ? 0.55 : 0.3)
    }

    Rectangle {                       // Griff
        x: root.pos; anchors.verticalCenter: parent.verticalCenter
        width: root.knob; height: root.knob; radius: root.knob / 2
        color: Theme.background
        border.width: 1
        border.color: Theme.primary
    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabled_
        hoverEnabled: true
        function update(mx) {
            let v = Math.max(0, Math.min(1, (mx - 4 - root.knob / 2) / (root.width - root.knob)))
            root.userSet(Math.round(v / root.step) * root.step)
        }
        onPressed: (e) => { root.engaged = true; update(e.x) }
        onPositionChanged: (e) => { if (pressed) update(e.x) }
        onContainsMouseChanged: if (!containsMouse && !pressed) root.engaged = false
        onReleased: if (!containsMouse) root.engaged = false
        // Mausrad: eine Raste (120) = 5 %; Touchpads schicken viele kleine Werte – die werden gesammelt
        property real wheelAcc: 0
        onWheel: (e) => {
            if (!root.wheelWanted()) { e.accepted = false; return }   // an die Seite weiterreichen
            const d = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x
            if (d === 0) return
            if ((d > 0) !== (wheelAcc > 0)) wheelAcc = 0              // Richtung gewechselt
            wheelAcc += d
            while (Math.abs(wheelAcc) >= 120) {
                const up = wheelAcc > 0
                root.nudge(up ? 0.05 : -0.05)
                wheelAcc -= up ? 120 : -120
            }
        }
    }
}
