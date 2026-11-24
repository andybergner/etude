import QtQuick

// Überschrift im Menü (shadcn: DropdownMenuLabel: px-2 py-1.5 text-sm font-medium)
Text {
    property string label: ""
    text: label
    leftPadding: 8; topPadding: 6; bottomPadding: 6
    color: Theme.mutedForeground
    font.family: Theme.fontSans
    font.pixelSize: 12
    font.weight: Font.Medium
}
