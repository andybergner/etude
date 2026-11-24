import QtQuick

// Trennlinie im Menü (shadcn: DropdownMenuSeparator: -mx-1 my-1 h-px bg-border)
Item {
    implicitHeight: 9
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: -4; width: parent.width + 8
        height: 1
        color: Theme.border
    }
}
