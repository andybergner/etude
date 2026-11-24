import QtQuick

// shadcn <Kbd>: Tastenkürzel-Anzeige
Rectangle {
    property alias text: label.text

    implicitWidth: Math.max(20, label.implicitWidth + 10)
    implicitHeight: 20
    radius: Theme.radiusSm
    color: Theme.muted
    border.width: 1
    border.color: Theme.border

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontSans
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Theme.mutedForeground
    }
}
