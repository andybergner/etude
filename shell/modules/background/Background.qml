import QtQuick
import Quickshell
import Quickshell.Wayland
import Etude.Ui

// Desktop-Hintergrund (ersetzt hyprpaper): unterste Ebene, ein Fenster pro Monitor.
// Beim Wechsel blendet das neue Bild weich über das alte.
PanelWindow {
    id: win

    property string source: ""               // Pfad zum Bild ("" = Farbton)
    property color tint: Theme.background    // Farbton, wenn kein Bild

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "etude-background"
    color: tint
    Behavior on color { ColorAnimation { duration: 400 } }

    property bool showA: true

    onSourceChanged: {
        const url = source ? "file://" + source : ""
        if (showA) imgB.source = url; else imgA.source = url
        showA = !showA
    }

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: win.showA && status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }
    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: !win.showA && status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }
}
