import QtQuick
import QtQuick.Layouts

// Monatskalender (shadcn: Calendar) – Woche beginnt am Montag, mit Kalenderwochen.
// Heute = bg-accent, ausgewählter Tag = bg-primary, Tage anderer Monate = muted.
Item {
    id: root

    property date today: new Date()
    property date selected: today
    property int year: today.getFullYear()
    property int month: today.getMonth()          // 0-11
    property bool showWeekNumbers: true
    property real cellSize: 36

    signal daySelected(date d)

    // Kurznamen der Wochentage ab Montag in der Sprache von Etude (Mo, Di … / Mo, Tu …)
    readonly property var weekdays: [1, 2, 3, 4, 5, 6, 0].map(d => I18n.locale.dayName(d, Locale.ShortFormat).replace(".", "").slice(0, 2))
    readonly property string monthTitle: new Date(year, month, 1).toLocaleDateString(I18n.locale, "MMMM yyyy")

    function prevMonth() { if (month === 0) { month = 11; year-- } else month-- }
    function nextMonth() { if (month === 11) { month = 0; year++ } else month++ }
    function goToday() { year = today.getFullYear(); month = today.getMonth(); selected = today }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }
    // ISO-Kalenderwoche
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }
    // 6 Wochen x 7 Tage ab dem Montag vor dem Monatsersten
    readonly property var days: {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7       // Montag = 0
        const out = []
        for (let i = 0; i < 42; i++) out.push(new Date(year, month, 1 - offset + i))
        return out
    }

    implicitWidth: grid.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        // Kopf: ‹  November 2026  ›
        RowLayout {
            Layout.fillWidth: true
            Button { variant: "ghost"; size: "icon-sm"; iconStart: String.fromCodePoint(0xF0141); onClicked: root.prevMonth() }  // md-chevron_left
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.monthTitle
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            Button { variant: "ghost"; size: "icon-sm"; iconStart: String.fromCodePoint(0xF0142); onClicked: root.nextMonth() }  // md-chevron_right
        }

        GridLayout {
            id: grid
            columns: root.showWeekNumbers ? 8 : 7
            rowSpacing: 2
            columnSpacing: 2

            // Kopfzeile
            Item { visible: root.showWeekNumbers; implicitWidth: root.cellSize * 0.8; implicitHeight: 24
                Text { anchors.centerIn: parent; text: I18n.t("common.calendarWeek"); color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 11 } }
            Repeater {
                model: root.weekdays
                Item {
                    required property string modelData
                    implicitWidth: root.cellSize; implicitHeight: 24
                    Text { anchors.centerIn: parent; text: parent.modelData; color: Theme.mutedForeground; font.family: Theme.fontSans; font.pixelSize: 12 }
                }
            }

            // 6 Wochen: je eine KW-Zelle + 7 Tage
            Repeater {
                model: root.showWeekNumbers ? 48 : 42
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property int cols: root.showWeekNumbers ? 8 : 7
                    readonly property bool isWeekCell: root.showWeekNumbers && index % 8 === 0
                    readonly property int dayIndex: root.showWeekNumbers ? Math.floor(index / 8) * 7 + (index % 8) - 1 : index
                    readonly property date day: isWeekCell ? root.days[Math.floor(index / 8) * 7] : root.days[dayIndex]
                    readonly property bool inMonth: day.getMonth() === root.month
                    readonly property bool isToday: root.sameDay(day, root.today)
                    readonly property bool isSelected: root.sameDay(day, root.selected)

                    implicitWidth: isWeekCell ? root.cellSize * 0.8 : root.cellSize
                    implicitHeight: root.cellSize

                    Rectangle {
                        anchors.fill: parent
                        visible: !cell.isWeekCell
                        radius: Theme.radiusMd
                        color: cell.isSelected ? Theme.primary
                             : cell.isToday ? Theme.accent
                             : mouse.containsMouse ? Theme.accent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.isWeekCell ? root.isoWeek(cell.day) : cell.day.getDate()
                        color: cell.isWeekCell ? Theme.mutedForeground
                             : cell.isSelected ? Theme.primaryForeground
                             : cell.inMonth ? Theme.foreground : Theme.mutedForeground
                        opacity: cell.isWeekCell || cell.inMonth || cell.isSelected ? 1 : 0.5
                        font.family: Theme.fontSans
                        font.pixelSize: cell.isWeekCell ? 11 : 13
                        font.weight: cell.isToday || cell.isSelected ? Font.Medium : Font.Normal
                    }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: mouse
                        anchors.fill: parent
                        enabled: !cell.isWeekCell
                        hoverEnabled: true
                        onClicked: {
                            root.selected = cell.day
                            if (!cell.inMonth) { root.year = cell.day.getFullYear(); root.month = cell.day.getMonth() }
                            root.daySelected(cell.day)
                        }
                    }
                }
            }
        }
    }
}
