import QtQuick
import Etude.Ui

// Aufbau der Taskleiste als Desktop-Vorschau: alle Module, die nicht in der Leiste
// sind, liegen auf dem Desktop; per Ziehen in die Leiste (und zurück).
Item {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property var layout: ({ left: [], center: [], right: [], hidden: [] })
    // Elemente, die es auf diesem Gerät nicht gibt (z. B. { battery: false }), werden nicht angezeigt
    property var available: ({})
    function shown(id) { return available[id] !== false }
    signal changed(var layout)

    readonly property var info: ({
        start:         { label: tr.t("taskbar.moduleStart"), glyph: 0 },
        workspaces:    { label: tr.t("taskbar.moduleDesktops"), glyph: 0xF0A1D },
        apps:          { label: tr.t("taskbar.moduleApps"), glyph: 0xF003B },
        network:       { label: tr.t("taskbar.moduleNetwork"), glyph: 0xF05A9 },
        bluetooth:     { label: tr.t("taskbar.moduleBluetooth"), glyph: 0xF00AF },
        sound:         { label: tr.t("taskbar.moduleSound"), glyph: 0xF057E },
        battery:       { label: tr.t("taskbar.moduleBattery"), glyph: 0xF0079 },
        notifications: { label: tr.t("taskbar.moduleNotifications"), glyph: 0xF009C },
        clock:         { label: tr.t("taskbar.moduleClock"), glyph: 0xF0954 }
    })

    // fehlende Elemente landen unter "Ausgeblendet"
    function expand(ids) { return (ids || []).reduce((a, id) => a.concat(id === "tray" ? ["network", "bluetooth", "sound", "battery"] : [id]), []) }
    function normalized(l) {
        const out = { left: expand(l.left), center: expand(l.center), right: expand(l.right), hidden: expand(l.hidden) }
        const all = out.left.concat(out.center, out.right, out.hidden)
        for (const k in info) if (all.indexOf(k) < 0) out.hidden.push(k)
        return out
    }
    readonly property var model: normalized(layout)

    function move(id, zone, index) {
        const l = normalized(layout)
        // index zählt nur die sichtbaren Elemente → auf die volle Liste umrechnen
        const vis = l[zone].filter(x => shown(x) && x !== id)
        index = index >= vis.length ? l[zone].length : l[zone].indexOf(vis[index])
        for (const z of ["left", "center", "right", "hidden"]) {
            const i = l[z].indexOf(id)
            if (i >= 0) { l[z].splice(i, 1); if (z === zone && i < index) index-- }
        }
        l[zone].splice(Math.max(0, Math.min(index, l[zone].length)), 0, id)
        root.changed(l)
    }

    // ---- Ziehen ----
    property string dragging: ""
    property string dropZone: ""          // Bereich unter dem Mauszeiger (für die Hervorhebung)
    property int dropIndex: -1

    // Bildschirm-Vorschau
    property string wallpaper: ""        // Pfad ("" = Farbton)
    property color tint: Theme.muted
    property bool barTop: false

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 16

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.25
            text: tr.t("taskbar.dragModulesFromTheDesktop")
            color: Theme.mutedForeground
            font.family: Theme.fontSans; font.pixelSize: 13
        }

        // ===== Desktop-Vorschau: Fenster mit den Modulen, Leiste unten (oder oben) =====
        Rectangle {
            id: desktop
            width: parent.width
            height: Math.max(260, Math.min(380, width * 0.45))
            radius: Theme.radiusLg
            color: root.tint
            border.width: 1
            border.color: Theme.border
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: root.wallpaper ? "file://" + root.wallpaper : ""
                sourceSize: Qt.size(960, 540)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // ----- Module direkt auf dem Desktop: alle, die nicht in der Leiste sind -----
            Item {
                id: area
                x: 1
                width: desktop.width - 2
                height: desktop.height - bar.height - 2
                y: root.barTop ? bar.height + 1 : 1

                // Hervorhebung beim Zurückziehen
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: root.dragging !== ""
                    radius: Theme.radiusLg
                    color: Theme.alpha(Theme.background, root.dropZone === "hidden" ? 0.35 : 0.15)
                    border.width: 1
                    border.color: Theme.alpha(Theme.primary, root.dropZone === "hidden" ? 0.9 : 0.35)
                }

                Flow {
                    id: pool
                    readonly property var items: (root.model.hidden || []).filter(id => root.shown(id))
                    width: Math.min(area.width - 48, implicitW)
                    // Breite aller Module in einer Zeile (zum Zentrieren)
                    readonly property real implicitW: {
                        let w = 0
                        for (let i = 0; i < children.length; i++) if (children[i].wid !== undefined) w += children[i].width + spacing
                        return Math.max(0, w - spacing)
                    }
                    anchors.centerIn: parent
                    spacing: 10
                    Repeater {
                        model: pool.items
                        Chip {
                            required property var modelData
                            wid: modelData
                            labeled: true
                            opacity: root.dragging === modelData ? 0.3 : 1
                        }
                    }
                }
                Text {
                    visible: pool.items.length === 0
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: tr.t("taskbar.allModulesInBar")
                    color: Theme.foreground
                    style: Text.Raised
                    styleColor: Theme.alpha(Theme.background, 0.6)
                    font.family: Theme.fontSans; font.pixelSize: 13
                }
                DropArea {
                    anchors.fill: parent
                    keys: ["etude-barwidget"]
                    onEntered: { root.dropZone = "hidden"; root.dropIndex = -1 }
                    onExited: root.dropZone = ""
                    onDropped: {
                        const id = root.dragging
                        Qt.callLater(() => root.move(id, "hidden", 9999))   // ans Ende
                    }
                }
            }

            // ----- die Leiste -----
            Rectangle {
                id: bar
                x: 1
                width: parent.width - 2
                height: 50
                y: root.barTop ? 1 : parent.height - height - 1
                color: Theme.alpha(Theme.sidebar, 0.96)
                radius: desktop.radius - 1            // äußere Ecken wie der Desktop
                // innere Ecken eckig
                Rectangle {
                    width: parent.width; height: parent.radius
                    y: root.barTop ? parent.height - height : 0
                    color: parent.color
                }
                Rectangle {
                    width: parent.width; height: 1
                    y: root.barTop ? parent.height - 1 : 0
                    color: Theme.sidebarBorder
                }

                // wie die echte Leiste: links bündig, Mitte zentriert, rechts bündig
                ZoneRow { id: leftZone;   zone: "left";   x: 8 }
                ZoneRow { id: centerZone; zone: "center"; x: (bar.width - width) / 2 }
                ZoneRow { id: rightZone;  zone: "right";  x: bar.width - width - 8 }

                // Grenzen zwischen den Bereichen (Mitte bekommt mindestens 120 px, auch wenn sie leer ist)
                readonly property real cut1: Math.min(centerZone.x - 6, bar.width / 2 - 60)
                readonly property real cut2: Math.max(centerZone.x + centerZone.width + 6, bar.width / 2 + 60)
                function zoneAt(px) { return px < cut1 ? leftZone : px > cut2 ? rightZone : centerZone }

                // Hinweis auf die leere Mitte beim Ziehen
                Rectangle {
                    visible: root.dragging !== "" && centerZone.items.length === 0
                    x: bar.cut1 + 4; y: 7
                    width: bar.cut2 - bar.cut1 - 8
                    height: bar.height - 14
                    radius: Theme.radiusMd
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(Theme.foreground, root.dropZone === "center" ? 0.6 : 0.2)
                    Text { anchors.centerIn: parent; text: tr.t("taskbar.center"); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                }

                // Hervorhebung beim Ziehen
                Rectangle {
                    anchors.fill: parent
                    visible: root.dragging !== ""
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.alpha(Theme.primary, ["left", "center", "right"].indexOf(root.dropZone) >= 0 ? 0.9 : 0.35)
                    radius: bar.radius
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["etude-barwidget"]
                    function update(d) { const z = bar.zoneAt(d.x); root.dropZone = z.zone; root.dropIndex = z.indexAt(d.x - z.x) }
                    onEntered: (d) => update(d)
                    onPositionChanged: (d) => update(d)
                    onExited: { root.dropZone = ""; root.dropIndex = -1 }
                    onDropped: (d) => {
                        const z = bar.zoneAt(d.x)
                        const id = root.dragging, zn = z.zone, idx = z.indexAt(d.x - z.x)
                        Qt.callLater(() => root.move(id, zn, idx))   // erst nach dem Ziehen ändern
                    }
                }
            }
        }
    }

    // ---- Element: sieht aus wie in der echten Leiste, Name als Tooltip ----
    component Chip: Rectangle {
        id: chip
        property string wid: ""
        property bool isGhost: false
        property string place: "right"      // Bereich in der Leiste (für die Uhr)
        property bool labeled: false       // auf dem Desktop: Name neben dem Symbol
        width: content.implicitWidth + (labeled ? 24 : 16)
        height: 38
        radius: Theme.radiusMd
        color: isGhost ? Qt.rgba(Theme.popover.r, Theme.popover.g, Theme.popover.b, 1)
             : chipMouse.containsMouse ? Theme.sidebarAccent
             : labeled ? Theme.background : "transparent"
        border.width: isGhost || labeled || chipMouse.containsMouse ? 1 : 0
        border.color: isGhost ? Theme.primary : Theme.sidebarBorder
        readonly property color fg: Theme.sidebarForeground

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6
            // Start
            EtudeLogo { visible: chip.wid === "start"; anchors.verticalCenter: parent.verticalCenter; size: 17; monoColor: chip.fg }
            // Desktops: aktiver als Punkt
            Row {
                visible: chip.wid === "workspaces"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle { width: 7; height: 7; radius: 3.5; color: chip.fg; anchors.verticalCenter: parent.verticalCenter }
                Repeater { model: ["2", "3", "4"]; Text { required property var modelData; text: modelData; color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.Medium } }
            }
            // Apps: drei Beispiel-Icons
            Row {
                visible: chip.wid === "apps"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Repeater {
                    model: [0xF024B, 0xF018D, 0xF0493]
                    Text { required property var modelData; text: String.fromCodePoint(modelData); color: chip.fg; font.family: Theme.fontIcon; font.pixelSize: 18 }
                }
            }
            // Netzwerk, Bluetooth, Sound, Akku, Benachrichtigungen: ein Symbol
            Text {
                visible: ["network", "bluetooth", "sound", "battery", "notifications"].indexOf(chip.wid) >= 0
                anchors.verticalCenter: parent.verticalCenter
                text: chip.wid && root.info[chip.wid] && root.info[chip.wid].glyph ? String.fromCodePoint(root.info[chip.wid].glyph) : ""
                color: chip.fg
                font.family: Theme.fontIcon; font.pixelSize: 16
            }
            // Uhr: wie in der echten Leiste – links/rechts bündig, in der Mitte nebeneinander
            Grid {
                visible: chip.wid === "clock"
                anchors.verticalCenter: parent.verticalCenter
                columns: chip.place === "center" ? 2 : 1
                columnSpacing: 8
                horizontalItemAlignment: chip.place === "left" ? Grid.AlignLeft : Grid.AlignRight
                verticalItemAlignment: Grid.AlignVCenter
                Text { text: "09:41"; color: chip.fg; font.family: Theme.fontSans; font.pixelSize: chip.place === "center" ? 12 : 11; font.weight: Font.Medium }
                Text { text: "20.11.2026"; color: chip.fg; opacity: chip.place === "center" ? 0.75 : 1; font.family: Theme.fontSans; font.pixelSize: chip.place === "center" ? 12 : 11 }
            }
            Text {
                visible: chip.labeled
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 2
                text: chip.wid && root.info[chip.wid] ? root.info[chip.wid].label : ""
                color: chip.fg
                font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.Medium
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: !chip.isGhost
            enabled: !chip.isGhost
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: ghost
            drag.threshold: 4
            preventStealing: true          // nicht von der Seiten-Flickable übernehmen lassen
            onPressed: {
                const p = chip.mapToItem(root, 0, 0)
                ghost.wid = chip.wid
                ghost.x = p.x; ghost.y = p.y
            }
            drag.onActiveChanged: {
                if (drag.active) { root.dragging = chip.wid; ghost.Drag.active = true }
                else root.finishDrag()
            }
        }
        Tooltip {
            text: chip.wid && root.info[chip.wid] ? root.info[chip.wid].label : ""
            shown: !chip.labeled && chipMouse.containsMouse && root.dragging === ""
        }
    }

    // ---- Bereich: Elemente in einer Zeile mit Einfügemarke ----
    component ZoneRow: Row {
        id: zr
        property string zone: ""
        // nicht vorhandene Elemente bleiben im Aufbau gespeichert, werden hier aber nicht gezeigt
        readonly property var items: (root.model[zone] || []).filter(id => root.shown(id))
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: zr.items
            Chip {
                required property var modelData
                wid: modelData
                place: zr.zone
                opacity: root.dragging === modelData ? 0.3 : 1
            }
        }
        // Index der Einfügestelle für x (relativ zur Zeile)
        function indexAt(px) {
            let idx = 0
            for (let i = 0; i < children.length; i++) {
                const ch = children[i]
                if (ch.wid === undefined || ch.isMarker) continue
                if (px > ch.x + ch.width / 2) idx = items.indexOf(ch.wid) + 1
            }
            return idx
        }
        // Einfügemarke (liegt außerhalb des Zeilenflusses)
        Rectangle {
            readonly property bool isMarker: true
            visible: root.dropZone === zr.zone && root.dragging !== ""
            parent: zr.parent
            width: 2
            height: 28
            radius: 1
            y: zr.y + (zr.height - height) / 2
            color: Theme.primary
            x: {
                const kids = []
                for (let i = 0; i < zr.children.length; i++) if (zr.children[i].wid !== undefined) kids.push(zr.children[i])
                if (root.dropIndex < 0 || kids.length === 0) return zr.x - 3
                if (root.dropIndex >= kids.length) return zr.x + zr.width + 1
                return zr.x + kids[root.dropIndex].x - 3
            }
        }
    }

    function finishDrag() {
        ghost.Drag.drop()
        ghost.Drag.active = false
        dragging = ""
        dropZone = ""
        dropIndex = -1
    }

    Chip {
        id: ghost
        isGhost: true
        visible: root.dragging !== ""
        z: 100
        Drag.keys: ["etude-barwidget"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }
}
