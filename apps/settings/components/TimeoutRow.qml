import QtQuick
import Etude.Ui

// Zeile in einem Expander: Text links, Auswahl der Zeit rechts (wie Windows "… nach")
Item {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string label: ""
    property int minutes: 0
    signal picked(int minutes)

    readonly property var options: [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 120, 0].map(m => ({
        value: String(m),
        label: m === 0 ? tr.t("timeout.never") : m < 60 ? tr.tn("timeout.minutes", m).arg(m) : tr.tn("timeout.hours", m / 60).arg(m / 60)
    }))

    implicitHeight: 52

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 56
        anchors.right: sel.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }
    Select {
        id: sel
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 160
        model: root.options
        value: String(root.minutes)
        onActivated: (v) => root.picked(parseInt(v))
    }
}
