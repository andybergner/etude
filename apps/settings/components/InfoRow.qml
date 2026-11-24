import QtQuick
import Etude.Ui

// Eigenschaft: Name links, Wert rechts (markierbar zum Kopieren)
Item {
    id: root
    property string label: ""
    property string value: ""
    implicitHeight: 36
    visible: value !== ""

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }
    TextEdit {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.6)
        horizontalAlignment: Text.AlignRight
        readOnly: true
        selectByMouse: true
        wrapMode: Text.Wrap
        text: root.value
        color: Theme.foreground
        selectionColor: Theme.alpha(Theme.primary, 0.3)
        font.family: Theme.fontSans
        font.pixelSize: 13
    }
}
