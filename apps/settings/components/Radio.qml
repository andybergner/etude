import QtQuick
import Etude.Ui

// Auswahlkreis (nur Anzeige – geklickt wird die ganze Zeile)
Rectangle {
    property bool checked: false
    width: 18; height: 18; radius: 9
    color: "transparent"
    border.width: checked ? 5 : 1
    border.color: checked ? Theme.primary : Theme.input
    Behavior on border.width { NumberAnimation { duration: Theme.duration } }
}
