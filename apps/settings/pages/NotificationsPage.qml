import QtQuick
import Quickshell
import Etude.Ui
import "../components"

// System › Benachrichtigungen (wie Windows 11):
// Hauptschalter, Banner, Ton, Nicht stören, darunter die Apps einzeln.
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config         // Etude.Services/EtudeConfig

    spacing: 4

    readonly property var apps: (config.notifyApps || []).slice().sort((a, b) => a.name.localeCompare(b.name))
    readonly property var muted: config.notifyMuted || []

    function iconFor(i) {
        if (!i) return ""
        if (i.startsWith("/")) return "file://" + i
        if (i.indexOf("://") > 0) return i
        const e = DesktopEntries.byId(i)
        return Quickshell.iconPath(e ? e.icon : i, true)
    }
    function setMuted(app, mute) {
        const m = root.muted.filter(a => a !== app)
        if (mute) m.push(app)
        root.config.set("notifyMuted", m)
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF009C)
        label: tr.t("notifications.notifications")
        desc: tr.t("notifications.getNotificationsFromAppsAnd")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.notifyEnabled
            onToggled: root.config.set("notifyEnabled", !root.config.notifyEnabled)
        }
    }

    SettingRow {
        width: root.width
        visible: root.config.notifyEnabled
        chevron: false
        icon: String.fromCodePoint(0xF0379)
        label: tr.t("notifications.showBanners")
        desc: tr.t("notifications.brieflyShowNotificationsInThe")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.notifyBanners
            onToggled: root.config.set("notifyBanners", !root.config.notifyBanners)
        }
    }

    SettingRow {
        width: root.width
        visible: root.config.notifyEnabled && root.config.notifyBanners
        chevron: false
        icon: String.fromCodePoint(0xF0379)
        label: tr.t("notifications.position")
        desc: tr.t("notifications.positionDesc")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            model: [{ value: "auto", label: tr.t("notifications.posAuto") },
                    { value: "bottom-right", label: tr.t("notifications.posBottomRight") },
                    { value: "bottom-left", label: tr.t("notifications.posBottomLeft") },
                    { value: "top-right", label: tr.t("notifications.posTopRight") },
                    { value: "top-left", label: tr.t("notifications.posTopLeft") }]
            value: root.config.notifyPosition || "auto"
            onActivated: (v) => root.config.set("notifyPosition", v)
        }
    }

    SettingRow {
        width: root.width
        visible: root.config.notifyEnabled
        chevron: false
        icon: String.fromCodePoint(0xF057E)
        label: tr.t("notifications.playASound")
        desc: tr.t("notifications.whenANotificationArrives")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.notifySound
            onToggled: root.config.set("notifySound", !root.config.notifySound)
        }
    }

    SettingRow {
        width: root.width
        visible: root.config.notifyEnabled
        chevron: false
        icon: String.fromCodePoint(0xF009B)
        label: tr.t("notifications.doNotDisturb")
        desc: tr.t("notifications.notificationsGoStraightToThe")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.notifyDnd
            onToggled: root.config.set("notifyDnd", !root.config.notifyDnd)
        }
    }

    SettingRow {
        width: root.width
        visible: root.config.notifyEnabled
        chevron: false
        icon: String.fromCodePoint(0xF009E)
        label: tr.t("notifications.testNotification")
        desc: tr.t("notifications.showsASampleNotification")
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            // Art der Test-Benachrichtigung (wie shadcn/Sonner)
            Select {
                id: testKind
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                model: [{ value: "normal", label: tr.t("notifications.kindNormal") },
                        { value: "low", label: tr.t("notifications.kindLow") },
                        { value: "critical", label: tr.t("notifications.kindCritical") }]
                value: "normal"
                onActivated: (v) => testKind.value = v
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "outline"
                size: "sm"
                text: tr.t("notifications.send")
                onClicked: Quickshell.execDetached(["notify-send", "-a", tr.t("settings.settings"), "-i", "com.etude.settings",
                    "-u", testKind.value,
                    tr.t("notifications.testTitle"), tr.t("notifications.testBody")])
            }
        }
    }

    // ===== Apps =====
    SectionTitle {
        visible: root.config.notifyEnabled
        text: tr.t("notifications.notificationsFromAppsAndOther")
    }

    Rectangle {
        visible: root.config.notifyEnabled && root.apps.length === 0
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.card
        border.width: 1
        border.color: Theme.border
        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: tr.t("notifications.appsAppearHereOnceThey")
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
    }

    Repeater {
        model: root.config.notifyEnabled ? root.apps : []
        SettingRow {
            required property var modelData
            width: root.width
            chevron: false
            icon: String.fromCodePoint(0xF003B)
            iconSource: root.iconFor(modelData.icon)
            label: modelData.name
            desc: root.muted.indexOf(modelData.name) >= 0 ? I18n.t("common.off") : tr.t("notifications.bannerSound")
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.muted.indexOf(modelData.name) < 0
                onToggled: root.setMuted(modelData.name, root.muted.indexOf(modelData.name) < 0)
            }
        }
    }
}
