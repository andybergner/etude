import QtQuick
import Quickshell
import Etude.Ui
import "../components"

// Datenschutz & Sicherheit › Kamera: angeschlossene Kameras und welche Apps sie gerade benutzen.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var privacy         // Privacy.qml
    required property var audio           // Etude.Services/Audio (Kamera über PipeWire)

    spacing: 4

    function g(cp) { return String.fromCodePoint(cp) }

    // während die Seite offen ist alle 3 s nachsehen
    Timer { running: true; repeat: true; triggeredOnStart: true; interval: 3000; onTriggered: root.privacy.refreshCamera() }

    readonly property var users: root.privacy.cameraUsers.map(n => ({ name: n, icon: "" }))
        .concat(root.audio.videoCapture.filter(v => root.privacy.cameraUsers.indexOf(v.name) < 0))

    SettingRow {
        width: root.width
        chevron: false
        icon: root.g(0xF0100)
        label: root.privacy.cameras > 0 ? tr.t("camera.cameraFound") : tr.t("camera.noCameraFound")
        desc: root.privacy.cameras > 0 ? tr.tn("camera.devices", root.privacy.cameras).arg(root.privacy.cameras)
                                       : tr.t("camera.connectACameraToSee")
    }

    SectionTitle { text: tr.t("camera.currentlyUsedBy") }

    Rectangle {
        visible: root.users.length === 0
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            text: tr.t("camera.noAppIsUsingThe")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 13
        }
    }

    Repeater {
        model: root.users
        SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: root.g(0xF0100)
            iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
            label: modelData.name
            desc: tr.t("camera.usingTheCameraRightNow")
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: Theme.primary
            }
        }
    }
}
