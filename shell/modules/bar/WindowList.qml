// Fensterliste über einer App der Taskleiste (wie die Vorschau bei Windows 11).
// Erscheint beim Hover über einer App mit mehreren Fenstern und bleibt offen, solange die Maus
// auf der App oder auf der Liste ist.
//   Klick auf ein Fenster: nach vorne holen / minimieren / wiederherstellen
//   × : Fenster schließen
import Quickshell
import Quickshell.Wayland
import QtQuick
import Etude.Ui

PanelWindow {
    id: win
    property Translations tr: Translations { domain: "bar" }   // Texte dieses Moduls

    property var apps: null               // TaskApps (Daten und Aktionen)
    property Item target: null            // App-Button unter der Maus (oder null)
    property bool atBottom: true
    property bool suppressed: false       // z. B. wenn ein Menü offen ist
    property int delay: 400

    property string appKey: ""            // gezeigte App (die Buttons werden bei Änderungen neu erzeugt)
    readonly property var app: apps && appKey ? apps.findApp(appKey) : null
    property bool _show: false
    property real _x: 8
    property bool _dismissed: false

    function dismiss() { _dismissed = true; _show = false }
    function hasList(t) { return !!t && !!t.app && t.app.windows.length > 1 }

    onTargetChanged: {
        if (hasList(target)) {
            closeTimer.stop()
            if (target.app.key !== appKey) _dismissed = false
            if (_show && !_dismissed) place(target)        // schon offen: direkt zur neuen App wechseln
            else openTimer.restart()
        } else {
            openTimer.stop()
            closeTimer.restart()
        }
    }
    function place(t) {
        appKey = t.app.key
        const c = t.mapToItem(null, t.width / 2, 0).x
        const sw = win.screen ? win.screen.width : 1920
        _x = Math.round(Math.max(8, Math.min(sw - card.width - 8, c - card.width / 2)))
        _show = true
    }
    Timer {
        id: openTimer
        interval: win.delay
        onTriggered: if (win.hasList(win.target) && !win._dismissed) win.place(win.target)
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: if (!hover.hovered && !win.hasList(win.target)) win._show = false
    }
    // App weg oder nur noch ein Fenster → schließen
    onAppChanged: if (_show && (!app || app.windows.length < 2)) _show = false

    visible: _show && !suppressed && !!app
    color: "transparent"
    anchors { left: true; bottom: win.atBottom; top: !win.atBottom }
    margins { left: win._x; bottom: 6; top: 6 }
    implicitWidth: card.width
    implicitHeight: card.height
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "etude-windowlist"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 12
        radius: Theme.radiusLg
        color: Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
        border.width: 1
        border.color: Theme.border

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) closeTimer.restart(); else closeTimer.stop()
        }

        Column {
            id: col
            x: 6; y: 6
            width: parent.width - 12
            spacing: 2

            // Kopf: Icon und Name der App
            Item {
                width: parent.width
                height: 32
                Image {
                    id: appIcon
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    readonly property string icon: win.app ? win.app.icon || "" : ""
                    source: icon ? (icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true)) : ""
                    sourceSize: Qt.size(32, 32)
                    visible: status === Image.Ready
                }
                Text {
                    x: appIcon.visible ? 32 : 8
                    width: parent.width - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.app ? win.app.name + "  ·  " + win.tr.tn("bar.windowCount", win.app.windows.length).arg(win.app.windows.length) : ""
                    elide: Text.ElideRight
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                }
            }

            Repeater {
                model: win.app ? win.app.windows : []
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var w: modelData
                    readonly property bool minimized: win.apps.isMinimized(w)
                    readonly property bool focused: win.apps.isFocused(w)
                    width: col.width
                    height: 36
                    radius: Theme.radiusMd
                    color: rowMouse.containsMouse ? Theme.accent : "transparent"

                    // Fokus-Strich links
                    Rectangle {
                        visible: row.focused
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 16; radius: 1.5
                        color: Theme.primary
                    }
                    Text {
                        x: 12
                        width: parent.width - x - (closeBtn.visible ? 36 : 12) - (minTag.visible ? minTag.width + 8 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.w.o.title || (win.app ? win.app.name : "")
                        elide: Text.ElideRight
                        color: row.minimized ? Theme.mutedForeground : Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 13
                        font.weight: row.focused ? Font.Medium : Font.Normal
                    }
                    Rectangle {
                        id: minTag
                        visible: row.minimized
                        anchors.right: parent.right
                        anchors.rightMargin: closeBtn.visible ? 36 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: minText.implicitWidth + 12
                        height: 20
                        radius: Theme.radiusSm
                        color: Theme.muted
                        Text {
                            id: minText
                            anchors.centerIn: parent
                            text: win.tr.t("bar.minimized")
                            color: Theme.mutedForeground
                            font.family: Theme.fontSans; font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: (m) => {
                            if (m.button === Qt.MiddleButton) win.apps.closeWindow(row.w)
                            else { win.apps.toggleWindow(row.w); win.dismiss() }
                        }
                    }
                    // Schließen
                    Rectangle {
                        id: closeBtn
                        visible: rowMouse.containsMouse || closeMouse.containsMouse
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        radius: Theme.radiusSm
                        color: closeMouse.containsMouse ? Theme.destructive : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF0156)
                            color: closeMouse.containsMouse ? "white" : Theme.mutedForeground
                            font.family: Theme.fontIcon; font.pixelSize: 16
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.apps.closeWindow(row.w)
                        }
                    }
                }
            }
        }
    }
}
