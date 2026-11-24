import QtQuick
import Quickshell
import Etude.Ui
import "../components"

// Autostart von Apps (wie Windows 11): Name, Status, aktivieren/deaktivieren.
// Gleiche Daten wie Einstellungen › Apps › Autostart (Etude.Services/AppManager).
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    required property var apps             // AppManager
    property string search: ""
    property string selected: ""
    readonly property var selectedEntry: apps.autostart.find(e => e.id === selected) || null
    readonly property var shown: apps.autostart.filter(e => !search.trim() || e.name.toLowerCase().indexOf(search.trim().toLowerCase()) >= 0)

    Component.onCompleted: apps.refresh()

    readonly property var columns: [
        { key: "name",   label: tr.t("tm.name"),     width: 0,   align: "left" },
        { key: "source", label: tr.t("tm.source"), width: 180, align: "left" },
        { key: "status", label: tr.t("tm.status"),   width: 140, align: "left" }
    ]

    PageHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: tr.t("tm.startupApps")
        Button {
            variant: "outline"; size: "sm"
            text: root.selectedEntry && root.selectedEntry.enabled ? tr.t("tm.disable") : tr.t("tm.enable")
            enabled: !!root.selectedEntry
            onClicked: root.apps.setAutostart(root.selectedEntry, !root.selectedEntry.enabled)
        }
    }

    TableHeader {
        id: tableHead
        anchors { left: parent.left; right: parent.right; top: head.bottom; rightMargin: 12 }
        columns: root.columns
        sortKey: "name"
        sortDesc: false
    }

    Text {
        visible: root.shown.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: tableHead.bottom
        anchors.topMargin: 32
        text: tr.t("tm.noStartupApps")
        color: Theme.mutedForeground
        font.family: Theme.fontSans; font.pixelSize: 13
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: tableHead.bottom; bottom: parent.bottom }
        clip: true
        model: root.shown
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: true                       // per Tab/Pfeil erreichbar, Pfeile wählen darin
        keyNavigationEnabled: false                  // Pfeile macht Keys.onPressed (am Rand weiter zum Nachbarn)
        function selectRow(i) { root.selected = root.shown[i].id; positionViewAtIndex(i, ListView.Contain) }
        onActiveFocusChanged: if (activeFocus && !root.selectedEntry && root.shown.length) selectRow(0)
        Keys.onPressed: (e) => {
            const i = FocusNav.listKey(e, root.shown.length, root.shown.findIndex(x => x.id === root.selected))
            if (i >= 0) { selectRow(i); e.accepted = true }
        }
        delegate: Item {
            id: rowItem
            required property var modelData
            width: list.width - 12
            height: 40
            readonly property bool selected: root.selected === modelData.id
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                radius: Theme.radiusMd
                color: rowItem.selected ? Theme.alpha(Theme.primary, 0.14) : "transparent"
                HoverLayer { shown: mouse.containsMouse; level: 0.6 }
            }
            MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.selected = rowItem.modelData.id; list.forceActiveFocus() } }
            Row {
                anchors.fill: parent
                Item {
                    width: rowItem.width - 320
                    height: rowItem.height
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Item {
                            width: 20; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: img
                                anchors.fill: parent
                                source: root.apps.iconSource(rowItem.modelData.icon)
                                sourceSize: Qt.size(40, 40)
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !img.visible
                                text: String.fromCodePoint(0xF003B)
                                color: Theme.mutedForeground
                                font.family: Theme.fontIcon; font.pixelSize: 16
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowItem.modelData.name
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                        }
                    }
                }
                Text {
                    width: 180
                    leftPadding: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.modelData.userPath && !rowItem.modelData.systemPath ? tr.t("tm.addedByYou") : tr.t("tm.system")
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 13
                }
                Text {
                    width: 140
                    leftPadding: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.modelData.enabled ? tr.t("tm.enabled") : tr.t("tm.disabled")
                    color: rowItem.modelData.enabled ? Theme.foreground : Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 13
                }
            }
        }
    }
}
