// Tooltip über den Buttons der Taskleiste (eigenes Fenster, die Leiste selbst ist zu niedrig).
// Erscheint nach kurzer Verzögerung mittig über dem Button, Klicks gehen hindurch.
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui

PanelWindow {
    id: win

    property Item target: null            // Button unter der Maus (oder null)
    property string text: ""
    property bool atBottom: true
    property bool suppressed: false       // z. B. wenn ein Menü offen ist
    property int delay: 500

    property bool _show: false
    property real _x: 8
    property bool _dismissed: false       // nach einem Klick bis zum nächsten Button aus

    function dismiss() { _dismissed = true; _show = false }

    onTargetChanged: {
        _dismissed = false
        _show = false
        if (target) timer.restart(); else timer.stop()
    }
    Timer {
        id: timer
        interval: win.delay
        onTriggered: {
            if (!win.target || win._dismissed) return
            const c = win.target.mapToItem(null, win.target.width / 2, 0).x
            const sw = win.screen ? win.screen.width : 1920
            win._x = Math.round(Math.max(8, Math.min(sw - bubble.width - 8, c - bubble.width / 2)))
            win._show = true
        }
    }

    visible: _show && !suppressed && text !== ""
    color: "transparent"
    anchors { left: true; bottom: win.atBottom; top: !win.atBottom }
    margins { left: win._x; bottom: 6; top: 6 }
    implicitWidth: bubble.width
    implicitHeight: bubble.height
    mask: Region {}                       // keine Eingaben – Klicks gehen hindurch
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "etude-tooltip"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // shadcn Tooltip: bg-foreground, text-background, text-xs
    Rectangle {
        id: bubble
        width: label.implicitWidth + 20
        height: label.implicitHeight + 12
        radius: Theme.radiusMd
        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 1)
        Text {
            id: label
            anchors.centerIn: parent
            text: win.text
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.15
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1)
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }
}
