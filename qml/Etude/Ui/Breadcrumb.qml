import QtQuick

// shadcn: Breadcrumb – text-sm, text-muted-foreground, Links mit hover:text-foreground,
// letzter Eintrag (BreadcrumbPage) in text-foreground, Trenner "/".
// Wird es eng, werden mittlere Einträge zu "…" (BreadcrumbEllipsis), dann fällt auch der erste weg,
// zuletzt wird der letzte Eintrag gekürzt. Eng heißt: compact gesetzt oder availableWidth reicht nicht.
//   Breadcrumb { items: [{ label: "Einstellungen", path: "system" }, …]; availableWidth: …; onNavigate: (p) => … }
Row {
    id: root

    property var items: []               // [{ label, path }]
    property string separator: "/"
    property bool compact: false
    property real availableWidth: -1     // Platz in px; -1 = unbegrenzt
    signal navigate(string path)

    spacing: 8

    FontMetrics { id: fm; font.family: Theme.fontSans; font.pixelSize: 14 }
    readonly property real gapWidth: 16 + fm.advanceWidth(separator)
    function widthOf(list) {
        let w = 0
        for (let i = 0; i < list.length; i++) w += fm.advanceWidth(list[i].label) + (i > 0 ? gapWidth : 0)
        return Math.ceil(w)
    }
    readonly property bool limited: availableWidth >= 0
    readonly property var shown: {
        const dots = { label: "…", path: "", ellipsis: true }
        let l = items
        if (items.length > 2 && (compact || (limited && widthOf(l) > availableWidth)))
            l = [items[0], dots, items[items.length - 1]]
        if (l.length > 1 && limited && widthOf(l) > availableWidth)
            l = items.length > 1 ? [dots, items[items.length - 1]] : l
        return l
    }
    // Platz für den letzten Eintrag (wird bei Bedarf mit „…“ gekürzt)
    readonly property real lastWidth: limited ? Math.max(0, availableWidth - widthOf(shown.slice(0, -1)) - (shown.length > 1 ? gapWidth : 0)) : -1

    Repeater {
        model: root.shown
        delegate: Row {
            id: crumb
            required property var modelData
            required property int index
            readonly property bool last: index === root.shown.length - 1
            readonly property bool link: !last && !modelData.ellipsis
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: crumb.last && root.lastWidth >= 0 ? Math.min(implicitWidth, root.lastWidth) : implicitWidth
                elide: Text.ElideRight
                text: crumb.modelData.label
                color: crumb.last || (crumb.link && mouse.containsMouse) ? Theme.foreground : Theme.mutedForeground
                font.family: Theme.fontSans
                font.pixelSize: 14
                Behavior on color { enabled: Theme.animate; ColorAnimation { duration: Theme.duration } }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: crumb.link
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigate(crumb.modelData.path)
                }
            }
            Text {
                visible: !crumb.last
                anchors.verticalCenter: parent.verticalCenter
                text: root.separator
                color: Theme.alpha(Theme.mutedForeground, 0.6)
                font.family: Theme.fontSans
                font.pixelSize: 14
            }
        }
    }
}
