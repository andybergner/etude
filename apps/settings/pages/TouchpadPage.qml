import QtQuick
import Etude.Ui
import "../components"

// Bluetooth & Geräte › Touchpad (wie Windows 11)
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var hypr          // HyprSettings.qml
    readonly property var t: hypr.touchpad

    spacing: 4

    SettingRow {
        visible: !root.hypr.hasTouchpad
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0741)
        label: tr.t("touchpad.noTouchpadDetected")
        desc: tr.t("touchpad.theSettingsAreSavedAnyway")
    }

    SectionTitle { text: tr.t("touchpad.taps"); topPadding: 0 }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0741)
        label: tr.t("touchpad.tapToClick")
        desc: tr.t("touchpad.tapOnceLeftClickWith")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.t.tap
            onToggled: root.hypr.setTouchpad({ tap: !root.t.tap })
        }
    }
    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF030C)
        label: tr.t("touchpad.turnOffWhileTypingOn")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.t.dwt
            onToggled: root.hypr.setTouchpad({ dwt: !root.t.dwt })
        }
    }

    SectionTitle { text: tr.t("touchpad.scrolling") }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF04E2)
        label: tr.t("touchpad.scrollingDirection")
        desc: root.t.natural ? tr.t("touchpad.contentFollowsYourFingers") : tr.t("touchpad.movingFingersDownScrollsDown")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "std", label: tr.t("touchpad.standard") }, { value: "nat", label: tr.t("touchpad.natural") }]
            value: root.t.natural ? "nat" : "std"
            onSelected: (v) => root.hypr.setTouchpad({ natural: v === "nat" })
        }
    }
    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF04C5)
        label: tr.t("touchpad.scrollingSpeed")
        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, Math.min(260, root.width * 0.35))
            // 0,2 … 2,0
            value: (root.t.scrollFactor - 0.2) / 1.8
            onMoved: (v) => root.hypr.setTouchpad({ scrollFactor: Math.round((0.2 + v * 1.8) * 10) / 10 })
        }
    }

    SectionTitle { text: tr.t("touchpad.gestures") }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF0ABF)
        label: tr.t("touchpad.threeFingerSwipe")
        desc: tr.t("touchpad.leftOrRightSwitchBetween")
    }
}
