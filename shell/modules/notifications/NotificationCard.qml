// Eine Benachrichtigung (Banner und Center) im Stil von shadcn/ui Toast:
//   [Symbol der Art]  Titel                                   [✕]
//                     Text (gedämpft)
//                     App · Zeit (nur im Center)
//                     [Aktionen]
// Kein App-Icon, kein Bild – die Dringlichkeit (NotifyType.js) zeigt das Symbol:
// Kritisch ⓧ (rot), Niedrig ⓘ, Standard ohne Symbol.
import QtQuick
import Quickshell.Services.Notifications
import Etude.Ui
import "NotifyType.js" as NotifyType

Item {
    id: root
    property Translations tr: Translations { domain: "notifications" }   // Texte dieses Moduls

    required property var notif                  // Quickshell Notification (oder gespeicherter Eintrag)
    property var service                         // NotificationService
    property bool banner: false                  // Banner: deckend mit Schatten, ✕ immer sichtbar
    property bool showApp: true                  // im Center steht die App schon im Gruppenkopf
    property real time: Date.now()
    property date now: new Date()

    readonly property bool critical: !!notif && notif.urgency === NotificationUrgency.Critical
    readonly property string kind: NotifyType.of(notif)
    readonly property int kindIcon: NotifyType.icon(kind)
    // wie shadcn: nur „Kritisch“ ist farbig, sonst Vordergrundfarbe
    readonly property color tone: kind === "critical" ? Theme.destructive : Theme.foreground
    readonly property var actions: notif ? (notif.actions || []).filter(a => a.identifier !== "default" && a.text !== "") : []
    readonly property bool hovered: hover.hovered
    readonly property string body: notif ? (notif.body || "") : ""

    // Im zugeklappten Stapel hinten (Banner): nur die Kante zeigen, Inhalt ausblenden (wie Sonner)
    property bool peek: false
    property bool opaque: false                  // im Stapel deckend, damit die hinteren nicht durchscheinen

    implicitHeight: content.implicitHeight + 40

    function ago(t) {
        const s = Math.max(0, Math.floor((root.now.getTime() - t) / 1000))
        if (s < 60) return tr.t("notifications.now")
        if (s < 3600) return tr.t("notifications.minutesAgo").arg(Math.floor(s / 60))
        const d = new Date(t)
        if (d.toDateString() === root.now.toDateString()) return d.toLocaleTimeString(I18n.locale, Locale.ShortFormat)
        return I18n.locale.toString(d, tr.t("notifications.dateTimeFormat"))
    }

    // Schatten nur beim Banner
    Repeater {
        model: root.banner ? 4 : 0
        Rectangle {
            required property int index
            anchors.fill: parent
            anchors.margins: -(index + 1)
            radius: bg.radius + index + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.18 : 0.06) * (1 - index / 4))
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusLg
        color: root.banner ? Theme.alpha(Theme.popover, root.opaque ? 1 : Theme.glassPopover) : Theme.card
        border.width: 1
        border.color: Theme.border
        HoverLayer { radius: bg.radius; shown: root.hovered && !root.banner; level: 0.6 }
    }

    // Klick = Standardaktion (öffnet die App), mittlere Maustaste = schließen
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (e) => e.button === Qt.MiddleButton ? root.service.dismiss(root.notif) : root.service.activate(root.notif)
    }
    HoverHandler { id: hover }

    Item {
        id: content
        x: 16; y: 20
        width: parent.width - 32
        implicitHeight: textCol.implicitHeight
        opacity: root.peek ? 0 : 1
        // beim Zuklappen erst ausblenden, wenn der Banner hinten angekommen ist
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.peek ? 160 : 0 }
                NumberAnimation { duration: 90 }
            }
        }

        // Symbol der Art – senkrecht mittig in der Karte
        Text {
            id: kindGlyph
            visible: root.kindIcon !== 0
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 16 : 0
            height: 16
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: visible ? String.fromCodePoint(root.kindIcon) : ""
            color: root.tone
            font.family: Theme.fontIcon
            font.pixelSize: 16
        }

        Column {
            id: textCol
            anchors.left: kindGlyph.visible ? kindGlyph.right : parent.left
            anchors.leftMargin: kindGlyph.visible ? 12 : 0
            anchors.right: closeBtn.left
            anchors.rightMargin: 8
            spacing: 4

            Text {
                width: parent.width
                text: root.notif ? (root.notif.summary || "") : ""
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.foreground
                font.family: Theme.fontSans; font.pixelSize: 14
            }
            Text {
                width: parent.width
                text: root.body
                visible: text !== ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.banner ? 3 : 5
                elide: Text.ElideRight
                color: Theme.mutedForeground
                linkColor: Theme.primary
                font.family: Theme.fontSans; font.pixelSize: 13
                onLinkActivated: (l) => Qt.openUrlExternally(l)
            }
            // im Center: App und Zeit klein darunter
            Text {
                width: parent.width
                visible: !root.banner
                text: (root.showApp ? (root.notif && root.notif.appName ? root.notif.appName : root.tr.t("notifications.system")) + " · " : "")
                      + root.ago(root.time)
                elide: Text.ElideRight
                color: Theme.mutedForeground
                font.family: Theme.fontSans; font.pixelSize: 11
            }
            // Aktionen (z. B. "Antworten", "Öffnen")
            Row {
                visible: root.actions.length > 0
                width: parent.width
                topPadding: 4
                spacing: 8
                Repeater {
                    model: root.actions
                    Button {
                        required property var modelData
                        variant: root.kind === "critical" ? "destructive" : "outline"
                        size: "sm"
                        text: modelData.text
                        onClicked: root.service.invoke(root.notif, modelData)
                    }
                }
            }
        }

        // ✕ (Banner: immer, Center: beim Darüberfahren) – senkrecht mittig in der Karte
        Item {
            id: closeBtn
            anchors.right: parent.right
            anchors.rightMargin: -4
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            opacity: root.banner || root.hovered ? 1 : 0
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: "transparent"
                HoverLayer { color: Theme.accent; shown: closeMouse.containsMouse; level: closeMouse.pressed ? 0.6 : 1 }
            }
            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF0156)
                color: closeMouse.containsMouse ? Theme.foreground : Theme.mutedForeground
                font.family: Theme.fontIcon; font.pixelSize: 14
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.service.dismiss(root.notif)
            }
        }
    }
}
