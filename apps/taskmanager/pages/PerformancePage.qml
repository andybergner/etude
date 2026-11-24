import QtQuick
import Quickshell
import Quickshell.Io
import Etude.Ui
import "../components"

// Leistung (wie Windows 11): links die Geräte mit kleiner Verlaufsgrafik,
// rechts die große Grafik und die Kennzahlen des gewählten Geräts.
Item {
    id: root
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    required property var sys              // System.qml
    signal runTaskRequested()

    property string current: "cpu"
    property bool perCore: false           // CPU: Grafik je logischem Prozessor

    readonly property var h: sys.history
    function pct(v) { return Math.round((v || 0) * 100) + " %" }
    function ghz(mhz) { return mhz > 0 ? I18n.formatNumber(mhz / 1000, 2) + " GHz" : "–" }
    function last(a) { return a && a.length ? a[a.length - 1] : 0 }

    // Geräte in der linken Spalte
    readonly property var devices: {
        const d = [
            { id: "cpu", title: "CPU", sub: pct(sys.cpu) + "  " + ghz(sys.mhz), values: h.cpu || [], values2: [], max: 1 },
            { id: "mem", title: tr.t("tm.memory"),
              sub: sys.bytes(sys.mem.used) + " / " + sys.bytes(sys.mem.total) + " (" + pct((sys.mem.used || 0) / (sys.mem.total || 1)) + ")",
              values: h.mem || [], values2: [], max: 1 }
        ]
        sys.disks.forEach((k, i) => {
            const s = sys.diskStats[k.name] || { active: 0 }
            d.push({ id: "disk:" + k.name, title: tr.t("tm.diskTitle").arg(i).arg(k.name),
                     sub: (k.rotational ? "HDD" : "SSD") + "  " + pct(s.active), values: h["disk:" + k.name] || [], values2: [], max: 1 })
        })
        sys.nics.forEach(n => {
            const s = sys.netStats[n.name] || { rx: 0, tx: 0 }
            d.push({ id: "net:" + n.name, title: n.kind === "wifi" ? tr.t("tm.wifi") : "Ethernet",
                     sub: tr.t("tm.netSub").arg(sys.bits(s.tx)).arg(sys.bits(s.rx)),
                     values: h["net:" + n.name + ":rx"] || [], values2: h["net:" + n.name + ":tx"] || [], max: 0 })
        })
        if (sys.gpu >= 0) d.push({ id: "gpu", title: "GPU 0", sub: pct(sys.gpu), values: h.gpu || [], values2: [], max: 1 })
        return d
    }
    readonly property string kind: current.split(":")[0]
    readonly property string devName: current.split(":")[1] || ""

    // IPv4 des gewählten Netzwerkadapters
    property string ipv4: ""
    property string ipv6: ""
    onCurrentChanged: if (kind === "net") { ipProc.command = ["sh", "-c", "ip -4 -o addr show dev \"$1\" | awk '{print $4; exit}'; ip -6 -o addr show dev \"$1\" scope global | awk '{print $4; exit}'", "sh", devName]; ipProc.running = true }
    Process {
        id: ipProc
        stdout: StdioCollector { onStreamFinished: { const l = this.text.split("\n"); root.ipv4 = (l[0] || "").split("/")[0]; root.ipv6 = (l[1] || "").split("/")[0] } }
    }

    PageHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: tr.t("tm.performance")
        Button {
            variant: "ghost"; size: "sm"
            iconStart: String.fromCodePoint(0xF0415)
            text: tr.t("tm.runNewTask")
            onClicked: root.runTaskRequested()
        }
    }

    // ===== Geräte =====
    Flickable {
        id: side
        anchors { left: parent.left; top: head.bottom; bottom: parent.bottom; leftMargin: 12 }
        width: 250
        clip: true
        contentHeight: devCol.implicitHeight + 16
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: devCol
            width: parent.width
            spacing: 4
            Repeater {
                model: root.devices
                Rectangle {
                    id: tile
                    required property var modelData
                    width: devCol.width
                    height: 64
                    radius: Theme.radiusLg
                    color: root.current === modelData.id ? Theme.alpha(Theme.primary, 0.14) : "transparent"
                    HoverLayer { shown: tileMouse.containsMouse && root.current !== tile.modelData.id; level: 0.6 }
                    Graph {
                        id: mini
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 44
                        mini: true
                        values: tile.modelData.values
                        values2: tile.modelData.values2
                        maxValue: tile.modelData.max
                    }
                    Column {
                        anchors.left: mini.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: tile.modelData.title
                            color: Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: tile.modelData.sub
                            color: Theme.mutedForeground
                            font.family: Theme.fontSans; font.pixelSize: 12
                            font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.current = tile.modelData.id }
                }
            }
        }
    }

    // ===== Details =====
    Flickable {
        id: detail
        anchors { left: side.right; right: parent.right; top: head.bottom; bottom: parent.bottom; leftMargin: 16; rightMargin: 24 }
        clip: true
        contentHeight: detailCol.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: detailCol
            width: detail.width
            spacing: 12

            // Titel + Gerätename rechts
            Item {
                width: parent.width
                height: 36
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kind === "cpu" ? "CPU" : root.kind === "mem" ? tr.t("tm.memory")
                        : root.kind === "disk" ? tr.t("tm.diskDev").arg(root.devName)
                        : root.kind === "net" ? ((root.sys.nics.find(n => n.name === root.devName) || {}).kind === "wifi" ? tr.t("tm.wifi") : "Ethernet")
                        : "GPU"
                    color: Theme.foreground
                    font.family: Theme.fontSans; font.pixelSize: 24; font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.6)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    text: root.kind === "cpu" ? root.sys.cpuModel
                        : root.kind === "mem" ? root.sys.bytes(root.sys.mem.total)
                        : root.kind === "disk" ? ((root.sys.disks.find(d => d.name === root.devName) || {}).model || "")
                        : root.kind === "net" ? root.devName : ""
                    color: Theme.mutedForeground
                    font.family: Theme.fontSans; font.pixelSize: 14
                }
            }

            // Achsenbeschriftung oben
            Item {
                visible: !(root.kind === "cpu" && root.perCore)
                width: parent.width
                height: 16
                Text {
                    text: root.kind === "cpu" ? tr.t("tm.utilization") : root.kind === "mem" ? tr.t("tm.memoryUsage")
                        : root.kind === "disk" ? tr.t("tm.activeTime") : root.kind === "net" ? tr.t("tm.throughput") : tr.t("tm.utilization2")
                    color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    text: root.kind === "net" ? root.sys.bits(bigGraph.scaleMax) : "100 %"
                    color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
                }
            }

            // große Grafik
            Graph {
                id: bigGraph
                visible: !(root.kind === "cpu" && root.perCore)
                width: parent.width
                height: Math.max(180, Math.min(320, detail.height * 0.42))
                values: root.kind === "cpu" ? (root.h.cpu || [])
                      : root.kind === "mem" ? (root.h.mem || [])
                      : root.kind === "disk" ? (root.h["disk:" + root.devName] || [])
                      : root.kind === "net" ? (root.h["net:" + root.devName + ":rx"] || [])
                      : (root.h.gpu || [])
                values2: root.kind === "net" ? (root.h["net:" + root.devName + ":tx"] || []) : []
                maxValue: root.kind === "net" ? 0 : 1
            }

            // CPU: je logischem Prozessor
            Grid {
                visible: root.kind === "cpu" && root.perCore
                width: parent.width
                readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(root.sys.logical || 1)))
                columns: cols
                spacing: 6
                Repeater {
                    model: root.kind === "cpu" && root.perCore ? root.sys.logical : 0
                    Graph {
                        required property int index
                        width: (detailCol.width - (parent.cols - 1) * 6) / parent.cols
                        height: Math.max(60, Math.min(160, 320 / Math.ceil((root.sys.logical || 1) / parent.cols)))
                        values: root.h["core" + index] || []
                        grid: false
                    }
                }
            }

            Item {
                width: parent.width
                height: 16
                Text { text: tr.t("tm.60Seconds"); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                Text {
                    anchors.right: parent.right
                    visible: root.kind === "cpu"
                    text: root.perCore ? tr.t("tm.showOverallUtilization") : tr.t("tm.showLogicalProcessors")
                    color: Theme.primary; font.family: Theme.fontSans; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.perCore = !root.perCore }
                }
                Text {
                    anchors.right: parent.right
                    visible: root.kind === "net"
                    text: tr.t("tm.netLegend")
                    color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12
                }
                Text { anchors.right: parent.right; visible: root.kind !== "cpu" && root.kind !== "net"; text: "0"; color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
            }

            // Datenträger: zweite Grafik mit Übertragungsrate
            Column {
                visible: root.kind === "disk"
                width: parent.width
                spacing: 4
                Item {
                    width: parent.width
                    height: 16
                    Text { text: tr.t("tm.transferRate"); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                    Text { anchors.right: parent.right; text: root.sys.rate(rateGraph.scaleMax); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                }
                Graph {
                    id: rateGraph
                    width: parent.width
                    height: 90
                    maxValue: 0
                    values: root.h["disk:" + root.devName + ":read"] || []
                    values2: root.h["disk:" + root.devName + ":write"] || []
                }
            }

            Item { width: 1; height: 4 }

            // ===== Kennzahlen =====
            Row {
                width: parent.width
                spacing: 32

                // links: große Werte
                Flow {
                    width: (parent.width - 32) * 0.55
                    spacing: 24
                    Repeater {
                        model: root.kind === "cpu" ? [
                                { l: tr.t("tm.utilization2"), v: root.pct(root.sys.cpu) },
                                { l: tr.t("tm.speed"), v: root.ghz(root.sys.mhz) },
                                { l: tr.t("tm.processes"), v: String(root.sys.processes.length) },
                                { l: tr.t("tm.threads"), v: String(root.sys.threadCount) },
                                { l: tr.t("tm.upTime"), v: root.sys.duration(root.sys.uptime) } ]
                            : root.kind === "mem" ? [
                                { l: tr.t("tm.inUse"), v: root.sys.bytes(root.sys.mem.used) },
                                { l: tr.t("tm.available"), v: root.sys.bytes(root.sys.mem.available) },
                                { l: tr.t("tm.committed"), v: root.sys.bytes(root.sys.mem.committed) + " / " + root.sys.bytes(root.sys.mem.commitLimit) },
                                { l: tr.t("tm.cached"), v: root.sys.bytes(root.sys.mem.cached) },
                                { l: tr.t("tm.swap"), v: root.sys.mem.swapTotal > 0 ? root.sys.bytes(root.sys.mem.swapUsed) + " / " + root.sys.bytes(root.sys.mem.swapTotal) : tr.t("tm.none") } ]
                            : root.kind === "disk" ? [
                                { l: tr.t("tm.activeTime"), v: root.pct((root.sys.diskStats[root.devName] || {}).active) },
                                { l: tr.t("tm.readSpeed"), v: root.sys.rate((root.sys.diskStats[root.devName] || {}).read || 0) },
                                { l: tr.t("tm.writeSpeed"), v: root.sys.rate((root.sys.diskStats[root.devName] || {}).write || 0) } ]
                            : root.kind === "net" ? [
                                { l: tr.t("tm.send"), v: root.sys.bits((root.sys.netStats[root.devName] || {}).tx || 0) },
                                { l: tr.t("tm.receive"), v: root.sys.bits((root.sys.netStats[root.devName] || {}).rx || 0) } ]
                            : [ { l: tr.t("tm.utilization2"), v: root.pct(root.sys.gpu) } ]
                        Column {
                            required property var modelData
                            spacing: 2
                            Text { text: modelData.l; color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                            Text {
                                text: modelData.v
                                color: Theme.foreground
                                font.family: Theme.fontSans; font.pixelSize: 20; font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }

                // rechts: Angaben in zwei Spalten
                Grid {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 6
                    Repeater {
                        model: {
                            const nic = root.sys.nics.find(n => n.name === root.devName) || {}
                            const dk = root.sys.disks.find(d => d.name === root.devName) || {}
                            const rows = root.kind === "cpu" ? [
                                    [tr.t("tm.maximumSpeed"), root.sys.maxMhz > 0 ? root.ghz(root.sys.maxMhz) : "–"],
                                    [tr.t("tm.sockets"), String(root.sys.sockets)],
                                    [tr.t("tm.cores"), String(root.sys.cores)],
                                    [tr.t("tm.logicalProcessors"), String(root.sys.logical)] ]
                                : root.kind === "mem" ? [
                                    [tr.t("tm.total"), root.sys.bytes(root.sys.mem.total)],
                                    [tr.t("tm.free"), root.sys.bytes(root.sys.mem.free)],
                                    [tr.t("tm.shared"), root.sys.bytes(root.sys.mem.shmem)] ]
                                : root.kind === "disk" ? [
                                    [tr.t("tm.capacity"), root.sys.bytes(dk.size)],
                                    [tr.t("tm.type"), dk.rotational ? "HDD" : "SSD"],
                                    [tr.t("tm.device"), "/dev/" + root.devName] ]
                                : root.kind === "net" ? [
                                    [tr.t("tm.adapterName"), root.devName],
                                    [tr.t("tm.connectionType"), nic.kind === "wifi" ? tr.t("tm.wifi") : "Ethernet"],
                                    [tr.t("tm.speed2"), nic.speed > 0 ? nic.speed + " Mbit/s" : "–"],
                                    [tr.t("tm.ipv4Address"), root.ipv4 || "–"],
                                    [tr.t("tm.ipv6Address"), root.ipv6 || "–"] ]
                                : []
                            return [].concat(...rows)
                        }
                        Text {
                            required property var modelData
                            required property int index
                            text: modelData
                            color: index % 2 === 0 ? Theme.mutedForeground : Theme.foreground
                            font.family: Theme.fontSans; font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
