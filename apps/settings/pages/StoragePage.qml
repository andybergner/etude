import QtQuick
import Etude.Ui
import "../components"

// System › Speicher (Aufbau wie Windows 11):
//   Systemlaufwerk mit Belegung oben, darunter Belegung nach Kategorie,
//   tr.t("storage.temporaryFiles") zum Aufräumen und alle Laufwerke
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var storage       // Storage.qml

    spacing: 4

    Component.onCompleted: storage.refresh()

    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var r: storage.root_ || {}
    readonly property var s: storage.sizes || {}
    readonly property real total: r.size || 1

    // ===== Systemlaufwerk =====
    Rectangle {
        width: root.width
        height: 108
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Column {
            x: 20; y: 18
            width: parent.width - 40
            spacing: 10
            Row {
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.g(0xF02CA)
                    color: Theme.foreground
                    font.family: Theme.fontIcon
                    font.pixelSize: 22
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: tr.t("storage.system")
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.r.fs ? root.r.source + " · " + root.r.fs : ""
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                    }
                }
            }
            UsageBar { width: parent.width; value: root.r.percent || 0 }
            Item {
                width: parent.width
                height: 16
                Text {
                    text: tr.t("storage.used").arg(root.storage.human(root.r.used))
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    text: tr.t("storage.freeOf").arg(root.storage.human(root.r.avail)).arg(root.storage.human(root.r.size))
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
            }
        }
    }

    // ===== Belegung =====
    SectionTitle { text: tr.t("storage.usage") }

    Rectangle {
        width: root.width
        height: cats.implicitHeight + 8
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Column {
            id: cats
            y: 4
            width: parent.width
            Repeater {
                model: [
                    { label: tr.t("storage.systemAndPrograms"), icon: 0xF0493, key: "usr" },
                    { label: tr.t("storage.personalFiles"),  icon: 0xF02DC, key: "home" },
                    { label: tr.t("storage.documents"), icon: 0xF0219, key: "Dokumente" },
                    { label: tr.t("storage.pictures"), icon: 0xF02E9, key: "Bilder" },
                    { label: tr.t("storage.downloads"), icon: 0xF01DA, key: "Downloads" },
                    { label: tr.t("storage.videos"), icon: 0xF0567, key: "Videos" },
                    { label: tr.t("storage.music"), icon: 0xF075A, key: "Musik" },
                    { label: tr.t("storage.cache"),                icon: 0xF00E8, key: "cache" }
                ].filter(c => root.storage.scanning || root.s[c.key] !== undefined)
                delegate: Item {
                    id: cat
                    required property var modelData
                    width: cats.width
                    height: 52
                    readonly property real bytes: root.s[modelData.key]
                    Text {
                        id: cIco
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        text: root.g(modelData.icon)
                        color: Theme.foreground
                        font.family: Theme.fontIcon
                        font.pixelSize: 16
                    }
                    Column {
                        anchors.left: cIco.right; anchors.leftMargin: 16
                        anchors.right: parent.right; anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Item {
                            width: parent.width; height: 16
                            Text {
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                            }
                            Text {
                                anchors.right: parent.right
                                text: root.storage.scanning && isNaN(cat.bytes) ? tr.t("storage.calculating") : root.storage.human(cat.bytes)
                                color: Theme.mutedForeground
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                            }
                        }
                        UsageBar {
                            width: parent.width
                            implicitHeight: 4
                            value: (cat.bytes || 0) / root.total
                            fill: Theme.primary
                        }
                    }
                }
            }
        }
    }

    // ===== Temporäre Dateien =====
    SectionTitle { text: tr.t("storage.temporaryFiles") }

    Repeater {
        model: [
            { id: "trash",   label: tr.t("storage.recycleBin"),          desc: tr.t("storage.permanentlyRemoveDeletedFiles"), icon: 0xF0A79, key: "trash" },
            { id: "thumbs",  label: tr.t("storage.thumbnails"),   desc: tr.t("storage.thumbnailsAreRecreatedWhenNeeded"), icon: 0xF02E9, key: "thumbs" },
            { id: "pkg",     label: tr.t("storage.packageCache"),         desc: tr.t("storage.deleteOldPackageVersionsThe"), icon: 0xF03D3, key: "pkg" },
            { id: "journal", label: tr.t("storage.systemLogs"),    desc: tr.t("storage.limitTo100Mb"), icon: 0xF0219, key: "journal" }
        ]
        delegate: SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: root.g(modelData.icon)
            label: modelData.label + "  ·  " + (root.storage.scanning ? "…" : root.storage.human(root.s[modelData.key] || 0))
            desc: modelData.desc
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "outline"
                size: "sm"
                text: root.storage.cleaning === modelData.id ? tr.t("storage.running") : tr.t("storage.cleanUp")
                enabled: root.storage.cleaning === "" && (root.s[modelData.key] || 0) > 0
                onClicked: root.storage.clean(modelData.id)
            }
        }
    }

    Text {
        visible: root.storage.error !== ""
        width: root.width
        topPadding: 4
        text: root.storage.error
        wrapMode: Text.Wrap
        color: Theme.destructive
        font.family: Theme.fontSans
        font.pixelSize: 12
    }

    // ===== Laufwerke =====
    SectionTitle { text: tr.t("storage.drives") }

    Repeater {
        model: root.storage.drives
        delegate: Rectangle {
            required property var modelData
            width: root.width
            height: 76
            radius: Theme.radiusMd
            color: Theme.card
            border.width: 1
            border.color: Theme.border
            Text {
                id: dIco
                x: 20; y: 18
                text: root.g(modelData.mount === "/" ? 0xF02CA : modelData.mount.startsWith("/run/media") || modelData.mount.startsWith("/media") ? 0xF0553 : 0xF02CA)
                color: Theme.foreground
                font.family: Theme.fontIcon
                font.pixelSize: 18
            }
            Column {
                anchors.left: dIco.right; anchors.leftMargin: 16
                anchors.right: parent.right; anchors.rightMargin: 20
                y: 14
                spacing: 6
                Item {
                    width: parent.width; height: 18
                    Text {
                        text: modelData.mount + "  ·  " + modelData.source.split("/").pop() + "  ·  " + modelData.fs
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right
                        text: tr.t("storage.freeOf").arg(root.storage.human(modelData.avail)).arg(root.storage.human(modelData.size))
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                    }
                }
                UsageBar { width: parent.width; value: modelData.percent }
            }
        }
    }

    Row {
        topPadding: 8
        Button {
            variant: "ghost"
            size: "sm"
            text: root.storage.scanning ? tr.t("storage.calculating") : tr.t("storage.refresh")
            iconStart: root.g(0xF0450)
            enabled: !root.storage.scanning
            onClicked: root.storage.refresh()
        }
    }
}
