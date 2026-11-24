// Benachrichtigungscenter (Inhalt des eigenen Fensters):
// Kopf mit "Nicht stören" und "Alle löschen", darunter die Benachrichtigungen nach App gruppiert.
import QtQuick
import Quickshell
import Etude.Ui

Surface {
    id: root
    property Translations tr: Translations { domain: "notifications" }   // Texte dieses Moduls

    property var service                    // NotificationService
    property date now: new Date()
    property real maxHeight: 600

    width: Theme.menuWidth
    height: Math.min(maxHeight, head.height + body.height + 2)
    radius: Theme.radiusXl
    padding: 0

    // nach App gruppieren, Gruppen nach neuester Benachrichtigung sortiert
    readonly property var groups: {
        const out = []
        const idx = {}
        for (const n of (service ? service.list : [])) {
            const app = n.appName || ""
            if (idx[app] === undefined) { idx[app] = out.length; out.push({ app: app, first: n, items: [] }) }
            out[idx[app]].items.push(n)
        }
        return out
    }

    // ===== Kopf =====
    Item {
        id: head
        x: 1; y: 1
        width: parent.width - 2
        height: 52

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.tr.t("notifications.title")
            color: Theme.foreground
            font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Button {
                visible: root.service && root.service.count > 0
                variant: "ghost"
                size: "sm"
                text: root.tr.t("notifications.clearAll")
                onClicked: root.service.clearAll()
            }
            Item {
                width: dndBtn.width; height: dndBtn.height
                Button {
                    id: dndBtn
                    variant: root.service && root.service.dnd ? "secondary" : "ghost"
                    size: "icon-sm"
                    iconStart: String.fromCodePoint(root.service && root.service.dnd ? 0xF009B : 0xF009C)
                    onClicked: root.service.setDnd(!root.service.dnd)
                }
                Tooltip {
                    text: root.tr.t(root.service && root.service.dnd ? "notifications.dndOn" : "notifications.dnd")
                    shown: dndBtn.hovered
                }
            }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }
    }

    // ===== Liste =====
    Flickable {
        id: body
        x: 1
        anchors.top: head.bottom
        width: parent.width - 2
        height: Math.min(content.implicitHeight, root.maxHeight - head.height - 2)
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            topPadding: 12
            bottomPadding: 12
            spacing: 16

            // leer
            Text {
                visible: root.groups.length === 0
                width: parent.width
                height: 64
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.tr.t(root.service && root.service.dnd ? "notifications.noneDnd" : "notifications.none")
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 13
            }

            Repeater {
                model: root.groups

                Column {
                    id: group
                    required property var modelData
                    x: 12
                    width: content.width - 24
                    spacing: 8

                    // Gruppenkopf: App-Name und X für die ganze Gruppe (ohne App-Icon, wie shadcn)
                    Item {
                        width: parent.width
                        height: 24
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.right: gClose.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: group.modelData.app || root.tr.t("notifications.system")
                            elide: Text.ElideRight
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                        }
                        Button {
                            id: gClose
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            variant: "ghost"
                            size: "icon-xs"
                            iconStart: String.fromCodePoint(0xF0156)
                            onClicked: root.service.clearApp(group.modelData.app)
                        }
                    }

                    Repeater {
                        model: ScriptModel { values: group.modelData.items }
                        NotificationCard {
                            required property var modelData
                            notif: modelData
                            service: root.service
                            showApp: false
                            width: group.width
                            time: root.service.timeOf(modelData)
                            now: root.now
                        }
                    }
                }
            }
        }
    }
}
