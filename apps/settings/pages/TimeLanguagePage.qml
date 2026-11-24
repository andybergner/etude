import QtQuick
import Etude.Ui
import "../components"
import "../Nav.js" as Nav
import "../components/Languages.js" as Languages

// Zeit & Sprache (wie Windows): aktuelle Zeit, Zeitzone und Sprache oben, darunter die Unterpunkte
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var timedate      // TimeDate.qml
    required property var config        // EtudeConfig
    property date now: new Date()
    signal navigate(string path)

    spacing: 4

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Item {
        width: root.width
        height: 96
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: root.now.toLocaleTimeString(I18n.locale, root.config.clock24 ? "HH:mm" : "h:mm AP")
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 40
                font.weight: Font.DemiBold
            }
            Text {
                text: root.now.toLocaleDateString(I18n.locale, Locale.LongFormat)
                color: Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 13
            }
        }
        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: root.width > 520
            StatusTile { icon: String.fromCodePoint(0xF01E7); label: tr.t("time.timeZone"); desc: root.timedate.timezone || "–" }
            StatusTile { icon: String.fromCodePoint(0xF05CA); label: tr.t("time.language"); desc: Languages.name(root.timedate.locale) }
        }
    }

    Item { width: 1; height: 8 }

    Repeater {
        model: Nav.pagesT(tr, "time")
        delegate: SettingRow {
            required property var modelData
            width: root.width
            icon: modelData.icon
            label: modelData.label
            desc: modelData.desc
            onClicked: root.navigate("time/" + modelData.id)
        }
    }
}
