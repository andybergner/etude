import QtQuick
import QtQuick.Templates as T

// shadcn-Button für QML.
// Varianten: "default" | "outline" | "secondary" | "ghost" | "destructive" | "link"
// Größen:    "default" | "xs" | "sm" | "lg" | "icon" | "icon-xs" | "icon-sm" | "icon-lg"
//
//   Button { text: "Speichern" }
//   Button { text: "Löschen"; variant: "destructive"; iconStart: "" }
//   Button { variant: "outline"; size: "icon"; iconStart: "" }
T.Button {
    id: control

    property string variant: "default"
    property string size: "default"
    property string iconStart: ""     // Glyph aus der Icon-Schrift (Theme.fontIcon)
    property string iconEnd: ""
    property bool invalid: false      // aria-invalid
    property bool expanded: false     // aria-expanded (z. B. offenes Menü)
    property bool hasPopup: false     // aria-haspopup: kein "Eindrücken" beim Klick

    // ---------- Größen ----------
    readonly property bool iconOnly: size.indexOf("icon") === 0
    readonly property var _sizes: ({
        "default": { h: 32, px: 10, pxIcon: 8, gap: 6, font: 14,   icon: 16, r: Theme.radiusLg },
        "xs":      { h: 24, px: 8,  pxIcon: 6, gap: 4, font: 12,   icon: 12, r: Math.min(Theme.radiusMd, 10) },
        "sm":      { h: 28, px: 10, pxIcon: 6, gap: 4, font: 12.8, icon: 14, r: Math.min(Theme.radiusMd, 12) },
        "lg":      { h: 36, px: 10, pxIcon: 8, gap: 6, font: 14,   icon: 16, r: Theme.radiusLg },
        "icon":    { h: 32, px: 0,  pxIcon: 0, gap: 0, font: 14,   icon: 16, r: Theme.radiusLg },
        "icon-xs": { h: 24, px: 0,  pxIcon: 0, gap: 0, font: 12,   icon: 12, r: Math.min(Theme.radiusMd, 10) },
        "icon-sm": { h: 28, px: 0,  pxIcon: 0, gap: 0, font: 14,   icon: 14, r: Math.min(Theme.radiusMd, 12) },
        "icon-lg": { h: 36, px: 0,  pxIcon: 0, gap: 0, font: 14,   icon: 16, r: Theme.radiusLg }
    })
    readonly property var s: _sizes[size] || _sizes["default"]

    implicitHeight: s.h
    implicitWidth: iconOnly ? s.h : implicitContentWidth + leftPadding + rightPadding
    leftPadding:  iconOnly ? 0 : (iconStart !== "" ? s.pxIcon : s.px)
    rightPadding: iconOnly ? 0 : (iconEnd !== ""   ? s.pxIcon : s.px)
    topPadding: 0
    bottomPadding: 0

    font.family: Theme.fontSans
    font.pixelSize: s.font
    font.weight: Font.Medium

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus          // per Tab erreichbar; Leertaste und Enter lösen aus
    Keys.onReturnPressed: control.clicked()
    Keys.onEnterPressed: control.clicked()
    Keys.onPressed: (e) => FocusNav.key(control, e)     // Pfeiltasten: zum Nachbarn
    readonly property bool ownFocusRing: true           // FocusRoot zeichnet keinen zusätzlichen Ring

    // disabled:opacity-50
    opacity: enabled ? 1 : 0.5

    // active:translate-y-px
    transform: Translate { y: control.pressed && !control.hasPopup ? 1 : 0 }

    // ---------- Farben je Variante ----------
    readonly property bool _hot: hovered || expanded

    readonly property color _bg: {
        const d = Theme.dark
        switch (variant) {
        case "outline":
            // dark:bg-input/30, dark:hover:bg-input/50 (Alpha wird multipliziert)
            if (d) return Theme.alpha(Theme.input, Theme.input.a * (_hot ? 0.5 : 0.3))
            return _hot ? Theme.muted : Theme.background
        case "secondary":
            return hovered ? Theme.mix(Theme.secondary, Theme.foreground, 0.05) : Theme.secondary
        case "ghost":
            // gleiche Grundfarbe mit Deckkraft 0 statt "transparent" (= Schwarz),
            // sonst blitzt die Farbanimation beim Hover kurz grau auf
            if (Theme.transparency) return _hot ? Theme.accent : Theme.alpha(Theme.accent, 0)
            if (!_hot) return Theme.alpha(Theme.muted, 0)
            return d ? Theme.alpha(Theme.muted, 0.5) : Theme.muted
        case "destructive":
            if (d) return Theme.alpha(Theme.destructive, hovered ? 0.3 : 0.2)
            return Theme.alpha(Theme.destructive, hovered ? 0.2 : 0.1)
        case "link":
            return "transparent"
        default:
            return hovered ? Theme.alpha(Theme.primary, 0.8) : Theme.primary
        }
    }

    readonly property color _fg: {
        switch (variant) {
        case "outline":
        case "ghost":       return Theme.foreground
        case "secondary":   return Theme.secondaryForeground
        case "destructive": return Theme.destructive
        case "link":        return Theme.primary
        default:            return Theme.primaryForeground
        }
    }

    readonly property color _border: {
        if (invalid) return Theme.dark ? Theme.alpha(Theme.destructive, 0.5) : Theme.destructive
        if (visualFocus) return variant === "destructive" ? Theme.alpha(Theme.destructive, 0.4) : Theme.ring
        if (variant === "outline") return Theme.dark ? Theme.input : Theme.border
        return "transparent"
    }

    readonly property color _ring: {
        if (invalid || variant === "destructive")
            return Theme.alpha(Theme.destructive, Theme.dark ? 0.4 : 0.2)
        return Theme.alpha(Theme.ring, 0.5)
    }

    // ---------- Hintergrund ----------
    background: Item {
        // focus-visible:ring-3 (bzw. aria-invalid:ring-3)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: control.s.r + 3
            color: "transparent"
            border.width: 3
            border.color: control._ring
            visible: control.visualFocus || control.invalid
        }

        Rectangle {
            anchors.fill: parent
            radius: control.s.r
            color: control._bg
            border.width: 1
            border.color: control._border
            Behavior on color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
            Behavior on border.color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
        }
    }

    // ---------- Inhalt: [Icon] Text [Icon] ----------
    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        Row {
            id: row
            anchors.centerIn: parent
            spacing: control.s.gap

            Text {
                visible: control.iconStart !== ""
                text: control.iconStart
                // Ziffern/Buchstaben mit normaler Schrift, echte Icons mit der Icon-Schrift
                font.family: /^[0-9A-Za-z]+$/.test(control.iconStart) ? Theme.fontSans : Theme.fontIcon
                font.weight: Font.Medium
                font.pixelSize: control.s.icon
                color: control._fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: !control.iconOnly && control.text !== ""
                text: control.text
                font.family: control.font.family
                font.pixelSize: control.font.pixelSize
                font.weight: control.font.weight
                color: control._fg
                elide: Text.ElideRight
                // link: hover:underline
                font.underline: control.variant === "link" && control.hovered
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
            }

            Text {
                visible: control.iconEnd !== ""
                text: control.iconEnd
                font.family: Theme.fontIcon
                font.pixelSize: control.s.icon
                color: control._fg
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Zeigefinger über klickbaren Buttons (Wayland: Cursor-Form kommt vom Compositor-Theme)
    HoverHandler {
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
