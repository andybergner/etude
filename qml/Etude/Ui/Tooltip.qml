import QtQuick

// shadcn: Tooltip – kleine dunkle Blase über dem Element (bg-foreground, text-background, text-xs)
//   Rectangle { … MouseArea { id: m; hoverEnabled: true }  Tooltip { text: "Blau"; shown: m.containsMouse } }
Rectangle {
    id: root

    property string text: ""
    property bool shown: false
    property int delay: 300                  // ms bis zum Einblenden

    z: 100
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: parent ? parent.top : undefined
    anchors.bottomMargin: 6
    width: label.implicitWidth + 24
    height: label.implicitHeight + 12
    radius: Theme.radiusMd
    color: Theme.foreground

    property bool _visible: false
    visible: opacity > 0
    opacity: _visible ? 1 : 0
    scale: _visible ? 1 : 0.95
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120 } }

    onShownChanged: shown ? timer.restart() : (timer.stop(), _visible = false)
    Timer { id: timer; interval: root.delay; onTriggered: root._visible = true }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.background
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
