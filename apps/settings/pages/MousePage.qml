import QtQuick
import Etude.Ui
import "../components"

// Bluetooth & Geräte › Maus (wie Windows 11)
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var hypr          // HyprSettings.qml
    readonly property var m: hypr.mouse

    spacing: 4

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF037D)
        label: tr.t("mouse.primaryMouseButton")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "left", label: tr.t("mouse.left") }, { value: "right", label: tr.t("mouse.right") }]
            value: root.m.leftHanded ? "right" : "left"
            onSelected: (v) => root.hypr.setMouse({ leftHanded: v === "right" })
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF04C5)
        label: tr.t("mouse.mousePointerSpeed")
        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, Math.min(260, root.width * 0.35))
            // Hyprland: -1 … 1, Slider: 0 … 1
            value: (root.m.sensitivity + 1) / 2
            onMoved: (v) => root.hypr.setMouse({ sensitivity: Math.round((v * 2 - 1) * 20) / 20 })
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF01C0)
        label: tr.t("mouse.pointerAcceleration")
        desc: tr.t("mouse.fastMovementsMoveThePointer")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.m.accel
            onToggled: root.hypr.setMouse({ accel: !root.m.accel })
        }
    }

    SectionTitle { text: tr.t("mouse.scrolling") }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF04E2)
        label: tr.t("mouse.scrollingDirection")
        desc: root.m.natural ? tr.t("mouse.contentFollowsYourFingersLike") : tr.t("mouse.scrollingTheWheelDownScrolls")
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "std", label: tr.t("mouse.standard") }, { value: "nat", label: tr.t("mouse.natural") }]
            value: root.m.natural ? "nat" : "std"
            onSelected: (v) => root.hypr.setMouse({ natural: v === "nat" })
        }
    }
}
