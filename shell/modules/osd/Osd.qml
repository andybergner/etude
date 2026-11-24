// OSD (On-Screen-Display) wie bei Windows 11: kleine Pille unten mittig über der Taskleiste.
// Zeigt Lautstärke, Helligkeit oder Mikrofon kurz an, wenn sie sich durch Tasten oder
// Mausrad ändern. Auslöser:
//   Tasten (bindings.lua):  wpctl … && qs -p $ETUDE_HOME/shell ipc call osd volume
//   Mausrad in der Leiste:  osd.show("volume")
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Etude.Ui
import Etude.Services
import "../bar/Icons.js" as Icons

Scope {
    id: root
    property Translations tr: Translations { domain: "osd" }   // Texte dieses Moduls

    property bool atBottom: true            // Taskleiste unten → OSD unten, sonst oben
    property string kind: "volume"          // "volume" | "brightness" | "mic"
    property bool shown: false

    Audio { id: audio }
    Brightness { id: brightness }

    function show(k) {
        kind = k
        if (k === "brightness") brightness.refresh()
        shown = true
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 1600; onTriggered: root.shown = false }

    //   qs -p $ETUDE_HOME/shell ipc call osd volume
    IpcHandler {
        target: "osd"
        function volume(): void { root.show("volume") }
        function brightness(): void { root.show("brightness") }
        function mic(): void { root.show("mic") }
    }

    readonly property real value: kind === "brightness" ? brightness.value
                                : kind === "mic" ? audio.sourceVolume : audio.volume
    readonly property bool muted: kind === "volume" ? audio.muted : kind === "mic" ? audio.sourceMuted : false
    readonly property string icon: {
        if (kind === "brightness") return String.fromCodePoint(value < 0.34 ? 0xF00DE : value < 0.67 ? 0xF00DF : 0xF00E0)
        if (kind === "mic") return String.fromCodePoint(muted ? 0xF036D : 0xF036C)
        if (muted || value <= 0) return Icons.volMute
        return value < 0.34 ? Icons.volLow : value < 0.67 ? Icons.volMedium : Icons.volHigh
    }

    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor
        const s = Quickshell.screens
        for (let i = 0; i < s.length; i++) if (m && s[i].name === m.name) return s[i]
        return s.length > 0 ? s[0] : null
    }

    PanelWindow {
        id: win
        screen: root.focusedScreen
        visible: root.shown || pill.opacity > 0
        color: "transparent"
        // nur unten (oder oben) verankert → waagerecht mittig, über der Leiste (exklusive Zone)
        anchors { bottom: root.atBottom; top: !root.atBottom }
        margins { bottom: 24; top: 24 }
        implicitWidth: pill.width
        implicitHeight: pill.height
        mask: Region {}                     // Klicks gehen hindurch
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etude-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: pill
            width: 260
            height: 48
            radius: height / 2
            color: Theme.alpha(Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1), Math.max(Theme.glassPopover, 0.9))
            border.width: 1
            border.color: Theme.border
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.95
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            // Icon
            Text {
                id: ico
                x: 18
                width: 22
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.icon
                color: root.muted ? Theme.mutedForeground : Theme.foreground
                font.family: Theme.fontIcon
                font.pixelSize: 20
            }

            // Mikrofon: Text statt Balken
            Text {
                visible: root.kind === "mic"
                anchors.left: ico.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.tr.t(root.muted ? "osd.micMuted" : "osd.micOn")
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 14
            }

            // Balken (wie shadcn Slider/Progress)
            Rectangle {
                id: track
                visible: root.kind !== "mic"
                anchors.left: ico.right
                anchors.leftMargin: 14
                anchors.right: valueText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Theme.alpha(Theme.foreground, 0.15)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.muted ? 0 : root.value))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
            Text {
                id: valueText
                visible: root.kind !== "mic"
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "–" : Math.round(root.value * 100)
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }
}
