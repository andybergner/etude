import QtQuick
import Etude.Ui
import "../components"

// System › Energie & Akku (Aufbau wie Windows 11):
//   Akku bzw. Netzbetrieb oben, Energiemodus,
//   tr.t("power.screenLockAndSleep") mit Zeiten für Netz- und Akkubetrieb
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var config        // EtudeConfig (Zeiten)
    required property var battery       // Etude.Services/Battery
    required property var power         // Etude.Services/PowerProfile

    spacing: 4

    Component.onCompleted: power.refresh()

    function g(cp) { return String.fromCodePoint(cp) }
    function duration(sec) {
        if (!sec || sec <= 0) return ""
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? I18n.t("common.durationHoursMinutes").arg(h).arg(m) : I18n.t("common.durationMinutes").arg(m)
    }
    function batteryIcon(level, charging) {
        if (charging) return g(0xF0084)
        const icons = [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
        return g(icons[Math.min(10, Math.round(level / 10))])
    }

    // ===== Akku / Netzbetrieb =====
    Rectangle {
        width: root.width
        height: 96
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.border

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Rectangle {
                width: 56; height: 56
                radius: Theme.radiusLg
                color: root.battery.present && root.battery.level < 15 && !root.battery.charging ? Theme.destructive : Theme.primary
                Text {
                    anchors.centerIn: parent
                    text: root.battery.present ? root.batteryIcon(root.battery.level, root.battery.charging) : root.g(0xF06A5)
                    color: Theme.primaryForeground
                    font.family: Theme.fontIcon
                    font.pixelSize: 28
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: root.battery.present ? root.battery.level + " %" : tr.t("power.pluggedIn")
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Text {
                    text: !root.battery.present ? tr.t("power.thisDeviceHasNoBattery")
                        : root.battery.charging
                            ? (root.duration(root.battery.secondsLeft) ? tr.t("power.chargingFullIn").arg(root.duration(root.battery.secondsLeft)) : tr.t("power.charging"))
                            : (root.duration(root.battery.secondsLeft) ? tr.t("power.onBatteryLeft").arg(root.duration(root.battery.secondsLeft)) : tr.t("power.onBattery"))
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }
        }
    }

    Item { width: 1; height: 8 }

    // ===== Energiemodus =====
    SettingRow {
        width: root.width
        chevron: false
        icon: g(0xF06A5)
        label: tr.t("power.powerMode")
        desc: root.power.available ? tr.t("power.balancePerformanceAndEnergyUse")
                                   : tr.t("power.notAvailableInstallSudoPacman")
        Select {
            visible: root.power.available
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            model: [
                { value: "power-saver", label: tr.t("power.bestPowerEfficiency") },
                { value: "balanced",    label: tr.t("power.balanced") },
                { value: "performance", label: tr.t("power.bestPerformance") }
            ]
            value: root.power.profile
            onActivated: (v) => root.power.set(v)
        }
    }

    // ===== Bildschirm, Sperren, Energiesparmodus =====
    SectionTitle { text: tr.t("power.screenLockAndSleep") }

    Expander {
        width: root.width
        expanded: true
        icon: g(0xF0379)
        label: root.battery.present ? tr.t("power.whenPluggedIn") : tr.t("power.timeouts")
        desc: tr.t("power.lockDeviceTurnOffScreen")

        TimeoutRow {
            width: root.width
            label: tr.t("power.lockDeviceAfter")
            minutes: root.config.idleAcLock
            onPicked: (m) => root.config.set("idleAcLock", m)
        }
        TimeoutRow {
            width: root.width
            label: tr.t("power.turnOffScreenAfter")
            minutes: root.config.idleAcScreen
            onPicked: (m) => root.config.set("idleAcScreen", m)
        }
        TimeoutRow {
            width: root.width
            label: tr.t("power.sleepAfter")
            minutes: root.config.idleAcSuspend
            onPicked: (m) => root.config.set("idleAcSuspend", m)
        }
    }

    Expander {
        visible: root.battery.present
        width: root.width
        expanded: true
        icon: g(0xF0079)
        label: tr.t("power.onBatteryPower")
        desc: tr.t("power.shorterTimesSaveBattery")

        TimeoutRow {
            width: root.width
            label: tr.t("power.lockDeviceAfter")
            minutes: root.config.idleBatLock
            onPicked: (m) => root.config.set("idleBatLock", m)
        }
        TimeoutRow {
            width: root.width
            label: tr.t("power.turnOffScreenAfter")
            minutes: root.config.idleBatScreen
            onPicked: (m) => root.config.set("idleBatScreen", m)
        }
        TimeoutRow {
            width: root.width
            label: tr.t("power.sleepAfter")
            minutes: root.config.idleBatSuspend
            onPicked: (m) => root.config.set("idleBatSuspend", m)
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: g(0xF033E)
        label: tr.t("power.lockBeforeSleep")
        desc: tr.t("power.theLockScreenAppearsWhen")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.lockOnSuspend
            onToggled: root.config.set("lockOnSuspend", !root.config.lockOnSuspend)
        }
    }
}
