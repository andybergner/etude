import QtQuick
import Etude.Ui
import "../components"

// System › Bildschirm (Aufbau wie Windows 11):
//   Anordnung der Bildschirme mit tr.t("display.identify"),
//   Helligkeit und Farbe (Helligkeit, Nachtlicht),
//   Skalierung und Layout (Skalierung, Auflösung, Bildwiederholrate, Ausrichtung)
Column {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    required property var displays      // Displays.qml
    required property var brightness    // Etude.Services/Brightness
    required property var config        // EtudeConfig (Nachtlicht)

    readonly property var m: displays.current
    readonly property bool multi: displays.monitors.length > 1

    spacing: 4

    Component.onCompleted: displays.refresh()

    function g(cp) { return String.fromCodePoint(cp) }

    // Auflösungen (eindeutig, größte zuerst) und Bildwiederholraten der gewählten Auflösung
    readonly property var resolutions: {
        if (!m) return []
        const seen = {}, out = []
        for (const s of m.modes) {
            const r = s.split("@")[0]
            if (!seen[r]) { seen[r] = true; out.push(r) }
        }
        return out.sort((a, b) => {
            const [aw, ah] = a.split("x").map(Number), [bw, bh] = b.split("x").map(Number)
            return bw * bh - aw * ah
        })
    }
    readonly property string currentRes: m ? m.width + "x" + m.height : ""
    readonly property var rates: m ? m.modes.filter(s => s.split("@")[0] === currentRes)
                                       .map(s => s.split("@")[1]).sort((a, b) => b - a) : []

    // ===== Bestätigung (wie Windows) =====
    Rectangle {
        visible: root.displays.confirming
        width: root.width
        height: 64
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.primary, 0.12)
        border.width: 1
        border.color: Theme.primary
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: confirmBtns.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: tr.t("display.keepQuestion").arg(root.displays.countdown)
            wrapMode: Text.Wrap
            color: Theme.foreground
            font.family: Theme.fontSans
            font.pixelSize: 13
        }
        Row {
            id: confirmBtns
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Button { size: "sm"; text: tr.t("display.keepChanges"); onClicked: root.displays.keep() }
            Button { size: "sm"; variant: "outline"; text: tr.t("display.revert"); onClicked: root.displays.revert() }
        }
    }

    // ===== Anordnung =====
    MonitorLayout {
        width: root.width
        monitors: root.displays.monitors
        selected: root.m ? root.m.name : ""
        onSelect: (name) => root.displays.selected = name
        onMoved: (name, x, y) => root.displays.change(name, { x: x, y: y })
    }

    Item {
        width: root.width
        height: 44
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.multi ? tr.t("display.dragDisplaysToRearrangeThem") : ""
            color: Theme.mutedForeground
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            variant: "outline"
            size: "sm"
            text: tr.t("display.identify")
            onClicked: root.displays.identify()
        }
    }

    // ===== Gewählter Bildschirm =====
    SettingRow {
        visible: !!root.m
        width: root.width
        chevron: false
        icon: g(0xF0379)
        label: root.m ? tr.t("display.monitorTitle").arg(root.m.id + 1).arg(root.m.description) : ""
        desc: root.m ? (root.m.disabled ? tr.t("display.monitorOff").arg(root.m.name)
                       : root.m.name + " · " + root.m.width + " × " + root.m.height + " · " + Math.round(root.m.refresh) + " Hz") : ""
        Switch {
            visible: root.multi
            anchors.verticalCenter: parent.verticalCenter
            checked: root.m ? !root.m.disabled : true
            // den letzten aktiven Bildschirm nicht ausschalten
            onToggled: if (root.m && (root.m.disabled || root.displays.monitors.filter(x => !x.disabled).length > 1))
                           root.displays.change(root.m.name, { disabled: !root.m.disabled })
        }
    }

    // ===== Helligkeit und Farbe =====
    SectionTitle { text: tr.t("display.brightnessColor") }

    SettingRow {
        visible: root.brightness.present
        width: root.width
        chevron: false
        icon: g(0xF00E0)
        label: tr.t("display.brightness")
        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, Math.min(260, root.width * 0.35))
            value: root.brightness.value
            onMoved: (v) => root.brightness.set(v)
        }
    }

    SettingRow {
        width: root.width
        chevron: false
        icon: g(0xF0594)
        label: tr.t("display.nightLight")
        desc: tr.t("display.warmerColorsInTheEvening")
        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.config.nightLight
            onToggled: root.config.set("nightLight", !root.config.nightLight)
        }
    }
    SettingRow {
        visible: root.config.nightLight
        width: root.width
        chevron: false
        icon: g(0xF050F)
        label: tr.t("display.strength")
        desc: root.config.nightTemp + " K"
        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, Math.min(260, root.width * 0.35))
            // 6000 K (schwach) … 2500 K (stark)
            value: (6000 - root.config.nightTemp) / 3500
            onMoved: (v) => root.config.set("nightTemp", Math.round((6000 - v * 3500) / 100) * 100)
        }
    }

    // ===== Skalierung und Layout =====
    SectionTitle { visible: root.m && !root.m.disabled; text: tr.t("display.scaleLayout") }

    SettingRow {
        visible: root.m && !root.m.disabled
        width: root.width
        chevron: false
        icon: g(0xF06ED)
        label: tr.t("display.scale")
        desc: tr.t("display.sizeOfTextAppsAnd")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            model: {
                const list = [1, 1.25, 1.5, 1.75, 2, 2.5, 3]
                if (root.m && list.indexOf(root.m.scale) < 0) list.push(root.m.scale)
                return list.sort((a, b) => a - b).map(s => ({ value: String(s), label: s === 1 ? tr.t("display.recommended").arg(Math.round(s * 100) + " %") : Math.round(s * 100) + " %" }))
            }
            value: root.m ? String(root.m.scale) : ""
            onActivated: (v) => root.displays.change(root.m.name, { scale: parseFloat(v) })
        }
    }

    SettingRow {
        visible: root.m && !root.m.disabled
        width: root.width
        chevron: false
        icon: g(0xF0A24)
        label: tr.t("display.displayResolution")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            model: root.resolutions.map((r, i) => ({ value: r, label: i === 0 ? tr.t("display.recommended").arg(r.replace("x", " × ")) : r.replace("x", " × ") }))
            value: root.currentRes
            searchable: false
            onActivated: (v) => {
                // höchste Bildwiederholrate dieser Auflösung nehmen
                const rate = root.m.modes.filter(s => s.split("@")[0] === v).map(s => s.split("@")[1]).sort((a, b) => b - a)[0] || "60.00"
                root.displays.change(root.m.name, { mode: v + "@" + rate })
            }
        }
    }

    SettingRow {
        visible: root.m && !root.m.disabled && root.rates.length > 0
        width: root.width
        chevron: false
        icon: g(0xF0450)
        label: tr.t("display.refreshRate")
        desc: tr.t("display.higherSmootherMotion")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            model: root.rates.map(r => ({ value: r, label: I18n.formatNumber(Math.round(parseFloat(r) * 100) / 100) + " Hz" }))
            value: root.m ? (root.rates.find(r => Math.abs(parseFloat(r) - root.m.refresh) < 0.05) || "") : ""
            onActivated: (v) => root.displays.change(root.m.name, { mode: root.currentRes + "@" + v })
        }
    }

    SettingRow {
        visible: root.m && !root.m.disabled
        width: root.width
        chevron: false
        icon: g(0xF0475)
        label: tr.t("display.displayOrientation")
        Select {
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            model: [
                { value: "0", label: tr.t("display.landscape") },
                { value: "1", label: tr.t("display.portrait") },
                { value: "2", label: tr.t("display.landscapeFlipped") },
                { value: "3", label: tr.t("display.portraitFlipped") }
            ]
            value: root.m ? String(root.m.transform % 4) : "0"
            onActivated: (v) => root.displays.change(root.m.name, { transform: parseInt(v) })
        }
    }
}
