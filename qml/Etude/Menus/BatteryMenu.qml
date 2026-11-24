import QtQuick
import QtQuick.Layouts
import Etude.Ui

// Akku-Menü: Ladestand, Restzeit, Energiemodus, Helligkeit
MenuPage {
    id: root
    property Translations tr: Translations { domain: "menus" }   // Texte dieses Moduls

    property int level: 100
    property bool charging: false
    property int secondsLeft: 0         // bis leer bzw. bis voll
    property string profile: "balanced" // "power-saver" | "balanced" | "performance"
    property bool profilesAvailable: true
    property bool hasBrightness: true
    property real brightness: 0.7

    signal setProfile(string p)
    signal setBrightness(real v)
    signal openSettings()

    title: tr.t("menus.battery")
    footerText: tr.t("menus.powerSettings")
    onFooterClicked: root.openSettings()

    function g(cp) { return String.fromCodePoint(cp) }
    function duration(s) {
        if (s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return h > 0 ? I18n.t("common.durationHoursMinutes").arg(h).arg(m) : I18n.t("common.durationMinutes").arg(m)
    }

    Column {
        width: parent.width
        spacing: 2

        // Ladestand
        RowLayout {
            width: parent.width
            height: 64
            spacing: 12
            Text {
                Layout.leftMargin: 10
                text: root.charging ? root.g(0xF0084) : root.g(0xF0081)
                color: root.level <= 15 && !root.charging ? Theme.destructive : Theme.foreground
                font.family: Theme.fontIcon; font.pixelSize: 30
            }
            Column {
                Layout.fillWidth: true
                Text { text: root.level + " %"; color: Theme.foreground; font.family: Theme.fontSans; font.pixelSize: 20; font.weight: Font.DemiBold }
                Text {
                    text: root.charging ? (root.secondsLeft > 0 ? root.tr.t("menus.fullIn").arg(root.duration(root.secondsLeft)) : root.tr.t("menus.charging"))
                                        : (root.secondsLeft > 0 ? root.tr.t("menus.remaining").arg(root.duration(root.secondsLeft)) : root.tr.t("menus.onBattery"))
                    color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
                }
            }
        }

        // Energiemodus (Segmente)
        SectionLabel { visible: root.profilesAvailable; text: root.tr.t("menus.powerMode") }
        Rectangle {
            visible: root.profilesAvailable
            width: parent.width
            height: 36
            radius: Theme.radiusMd
            color: Theme.muted
            Row {
                anchors.fill: parent
                anchors.margins: 3
                Repeater {
                    model: [
                        { id: "power-saver", label: root.tr.t("menus.powerSaver") },
                        { id: "balanced",    label: root.tr.t("menus.balanced") },
                        { id: "performance", label: root.tr.t("menus.performance") }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width) / 3
                        height: parent.height
                        radius: Theme.radiusSm
                        color: root.profile === modelData.id ? Theme.background : "transparent"
                        border.width: root.profile === modelData.id ? 1 : 0
                        border.color: Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.profile === modelData.id ? Theme.foreground : Theme.mutedForeground
                            font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setProfile(modelData.id) }
                    }
                }
            }
        }

        // Helligkeit
        SectionLabel { visible: root.hasBrightness; text: root.tr.t("menus.brightness") }
        RowLayout {
            visible: root.hasBrightness
            width: parent.width
            height: 40
            spacing: 8
            Text { Layout.leftMargin: 8; text: root.g(0xF00DF); color: Theme.foreground; font.family: Theme.fontIcon; font.pixelSize: 16 }
            Slider { Layout.fillWidth: true; Layout.leftMargin: 6; value: root.brightness; onMoved: (v) => root.setBrightness(v) }
            Text { Layout.preferredWidth: 30; Layout.rightMargin: 8; horizontalAlignment: Text.AlignRight
                   text: Math.round(root.brightness * 100); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
        }
    }
}
