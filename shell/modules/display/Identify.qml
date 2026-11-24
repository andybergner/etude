import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Etude.Ui

// "Identifizieren" aus den Einstellungen: große Nummer auf jedem Bildschirm (3 Sekunden)
Scope {
    id: root
    property bool shown: false

    function show() { root.shown = true; hide.restart() }
    Timer { id: hide; interval: 3000; onTriggered: root.shown = false }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.shown
            implicitWidth: 180
            implicitHeight: 180
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "etude-identify"

            readonly property var hmon: Hyprland.monitorFor(modelData)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusXl
                color: Theme.popover
                border.width: 1
                border.color: Theme.border
                Column {
                    anchors.centerIn: parent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.hmon ? win.hmon.id + 1 : "?"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: 88
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.modelData.name
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
