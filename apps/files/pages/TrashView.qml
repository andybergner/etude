import QtQuick
import Etude.Ui
import "../components"
import "../FileIcons.js" as Icons

// Papierkorb: gelöschte Elemente mit ursprünglichem Ort und Datum.
// Wiederherstellen oder endgültig löschen (Rechtsklick oder Befehlsleiste).
FocusScope {
    id: root
    property Translations tr: Translations { domain: "files" }   // Texte der App

    required property var ops              // FileOps.qml
    property string search: ""
    property var selected: ({})            // Name im Papierkorb → true
    readonly property var selectedNames: Object.keys(selected).filter(n => selected[n])
    readonly property int count: shown.length
    readonly property var shown: ops.trashItems.filter(t => !search.trim() || t.name.toLowerCase().indexOf(search.trim().toLowerCase()) >= 0)

    signal itemMenuRequested(real x, real y)
    signal backgroundMenuRequested(real x, real y)

    Component.onCompleted: ops.loadTrash()

    function click(name, mods) {
        if (mods & Qt.ControlModifier) { const s = Object.assign({}, selected); s[name] = !s[name]; selected = s }
        else { const s = {}; s[name] = true; selected = s }
    }
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Delete && selectedNames.length) { root.itemMenuRequested(-1, -1); e.accepted = true }
        else if (e.key === Qt.Key_A && (e.modifiers & Qt.ControlModifier)) {
            const s = {}; for (const t of shown) s[t.name] = true; selected = s; e.accepted = true
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => { root.selected = ({}); root.forceActiveFocus(); if (e.button === Qt.RightButton) root.backgroundMenuRequested(e.x, e.y) }
    }

    Column {
        visible: root.shown.length === 0
        anchors.centerIn: parent
        spacing: 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String.fromCodePoint(0xF0A7A)
            color: Theme.mutedForeground
            font.family: Theme.fontIcon; font.pixelSize: 40
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tr.t("files.theRecycleBinIsEmpty")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 14
        }
    }

    TableHeader {
        id: head
        visible: root.shown.length > 0
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 24 }
        columns: [
            { key: "name", label: tr.t("files.name"), width: 0, align: "left" },
            { key: "path", label: tr.t("files.originalLocation"), width: 260, align: "left" },
            { key: "date", label: tr.t("files.dateDeleted"), width: 150, align: "left" },
            { key: "size", label: tr.t("files.size"), width: 100, align: "right" }
        ]
        sortKey: "date"
        sortDesc: true
    }

    ListView {
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        clip: true
        model: root.shown
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: row
            required property var modelData
            width: ListView.view.width - 12
            height: 34
            readonly property bool sel: !!root.selected[modelData.name]
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: row.sel ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                HoverLayer { shown: mouse.containsMouse && !row.sel; level: 0.6 }
            }
            Row {
                anchors.fill: parent
                Item {
                    width: row.width - 510
                    height: row.height
                    FileIcon {
                        id: ic
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        size: 20
                        name: row.modelData.name
                        isDir: row.modelData.isDir
                    }
                    Text {
                        anchors.left: ic.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: row.modelData.path.split("/").pop()
                        color: Theme.foreground
                        font.family: Theme.fontSans; font.pixelSize: 13
                    }
                }
                Repeater {
                    model: [
                        { w: 260, t: row.modelData.path.slice(0, row.modelData.path.lastIndexOf("/")) || "/", r: false },
                        { w: 150, t: row.modelData.date.replace(/^(\d+)-(\d+)-(\d+)T(\d+:\d+).*/, "$3.$2.$1 $4"), r: false },
                        { w: 100, t: Icons.bytes(row.modelData.size, I18n.locale.decimalPoint), r: true }
                    ]
                    Text {
                        required property var modelData
                        width: modelData.w
                        height: row.height
                        leftPadding: 12
                        rightPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: modelData.r ? Text.AlignRight : Text.AlignLeft
                        elide: Text.ElideMiddle
                        text: modelData.t
                        color: Theme.mutedForeground
                        font.family: Theme.fontSans; font.pixelSize: 13
                    }
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (e) => {
                    root.forceActiveFocus()
                    if (e.button === Qt.RightButton) {
                        if (!root.selected[row.modelData.name]) root.click(row.modelData.name, 0)
                        const p = mapToItem(root, e.x, e.y)
                        root.itemMenuRequested(p.x, p.y)
                    } else root.click(row.modelData.name, e.modifiers)
                }
            }
        }
    }
}
