import QtQuick
import Etude.Ui

// Kleine Überschrift innerhalb eines Menüs
Text {
    width: parent ? parent.width : 200
    leftPadding: 10; topPadding: 8; bottomPadding: 4
    color: Theme.mutedForeground
    font.family: Theme.fontSans; font.pixelSize: 11; font.weight: Font.Medium
}
