import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Etude.Services
import Etude.Ui

// Bildauswahl für Hintergründe (Desktop, Sperrbildschirm): „Fotos durchsuchen“ und ein Raster
// mit gefundenen Bildern. current = gewähltes Bild, picked(path) beim Auswählen.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string current: ""
    signal picked(string path)

    property var images: []
    readonly property string home: Quickshell.env("HOME")
    // Hier wird nach Bildern gesucht (mitgelieferte Etude-Bilder zuerst)
    readonly property var folders: [
        Paths.home + "/default/wallpapers",           // mitgelieferte Etude-Bilder
        Paths.data + "/wallpapers",                 // eigene Hintergründe (~/.local/share/etude/wallpapers)
        home + "/Bilder/Wallpapers", home + "/Pictures/Wallpapers",
        home + "/Bilder", home + "/Pictures",
        "/usr/share/backgrounds"
    ]
    spacing: 4

    Process {
        running: true
        command: ["sh", "-c",
            "for d in \"$@\"; do [ -d \"$d\" ] && find \"$d\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort; done | awk '!seen[$0]++' | head -n 80",
            "sh"].concat(root.folders)
        stdout: StdioCollector {
            onStreamFinished: root.images = this.text.split("\n").filter(l => l)
        }
    }

    Row {
        topPadding: 12
        spacing: 8
        Button {
            variant: "outline"
            size: "sm"
            text: tr.t("background.browsePhotos")
            iconStart: String.fromCodePoint(0xF0976)
            onClicked: dialog.open()
        }
    }

    SectionTitle { text: tr.t("background.pictures") }

    Grid {
        id: grid
        width: root.width
        columns: Math.max(2, Math.floor((root.width + 12) / 172))
        spacing: 12
        Repeater {
            model: root.images
            delegate: Rectangle {
                id: tile
                required property string modelData
                readonly property bool active: root.current === modelData
                width: (grid.width - (grid.columns - 1) * grid.spacing) / grid.columns
                height: width * 0.5625
                radius: Theme.radiusMd
                color: Theme.muted
                border.width: active || activeFocus ? 2 : 1
                border.color: active ? Theme.primary : (mouse.containsMouse || activeFocus ? Theme.ring : Theme.border)
                clip: true
                // Tastatur: per Tab/Pfeil erreichbar, Enter/Leertaste wählt (FocusRoot)
                activeFocusOnTab: true
                signal clicked()
                onClicked: root.picked(tile.modelData)
                readonly property bool ownFocusRing: true
                Image {
                    anchors.fill: parent
                    anchors.margins: tile.active ? 3 : 1
                    source: "file://" + tile.modelData
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {                              // Haken
                    visible: tile.active
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 8
                    width: 22; height: 22; radius: 11
                    color: Theme.primary
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF012C)
                        color: Theme.primaryForeground
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.clicked()
                }
            }
        }
    }

    Text {
        visible: root.images.length === 0
        width: root.width
        topPadding: 4
        text: tr.t("background.noPicturesFoundPutPictures")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }

    FileDialog {
        id: dialog
        title: tr.t("background.chooseAWallpaper")
        nameFilters: [tr.t("background.imagesJpgJpegPngWebp")]
        onAccepted: {
            const path = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            if (root.images.indexOf(path) < 0) root.images = [path].concat(root.images)
            root.picked(path)
        }
    }
}
