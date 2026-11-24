import QtQuick
import Etude.Ui
import "../components"

// System › Multitasking: Fenster-Layout wählen
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string layout: "dwindle"
    signal setLayout(string layout)

    spacing: 12

    readonly property var layouts: [
        { id: "scrolling", label: "Scrolling",  desc: tr.t("multitasking.windowsAsColumnsScrollableSideways"),
          boxes: [[.22, 0, .56, 1], [-.36, 0, .56, 1], [.8, 0, .56, 1]] },
        { id: "floating",  label: "Floating",   desc: tr.t("multitasking.moveWindowsFreelyLikeOn"),
          boxes: [[.3, .3, .62, .62], [.06, .08, .55, .55]] },
        { id: "dwindle",   label: "Tiling",     desc: tr.t("multitasking.windowsShareTheSpaceAutomatically"),
          boxes: [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]] }
    ]

    Text {
        text: tr.t("multitasking.windowLayout")
        color: Theme.foreground
        font.family: Theme.fontSans
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    Text {
        width: root.width
        text: tr.t("multitasking.howNewWindowsAreArranged")
        wrapMode: Text.Wrap
        color: Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 13
    }

    Grid {
        id: grid
        width: root.width
        columns: root.width > 480 ? 3 : 1
        spacing: 12
        Repeater {
            model: root.layouts
            delegate: LayoutCard {
                required property var modelData
                // kompakt: höchstens 220 px breit
                width: Math.min(220, (grid.width - (grid.columns - 1) * grid.spacing) / grid.columns)
                label: modelData.label
                desc: modelData.desc
                boxes: modelData.boxes
                selected: root.layout === modelData.id
                onClicked: root.setLayout(modelData.id)
            }
        }
    }

    Item { width: 1; height: 12 }

    SettingRow {
        width: root.width
        chevron: false
        icon: String.fromCodePoint(0xF097B)
        label: tr.t("multitasking.keyboardShortcuts")
        desc: tr.t("multitasking.superFFloatASingle")
    }
}
