import QtQuick
import Etude.Ui

Rectangle {
    width: 760; height: 220
    color: Theme.background
    Column {
        anchors.centerIn: parent
        spacing: 16
        Row {
            spacing: 10
            Button { text: "Default" }
            Button { text: "Outline"; variant: "outline" }
            Button { text: "Secondary"; variant: "secondary" }
            Button { text: "Ghost"; variant: "ghost" }
            Button { text: "Destructive"; variant: "destructive" }
            Button { text: "Link"; variant: "link" }
        }
        Row {
            spacing: 10
            Button { text: "xs"; size: "xs" }
            Button { text: "sm"; size: "sm" }
            Button { text: "lg"; size: "lg" }
            Button { text: "Disabled"; enabled: false }
            Button { text: "Invalid"; variant: "outline"; invalid: true }
            Button { size: "icon"; variant: "outline"; text: "x" }
        }
    }
}
