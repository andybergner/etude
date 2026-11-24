import QtQuick

// Formularfeld wie bei shadcn: Label über dem Eingabefeld, darunter optional
// ein Hinweis oder eine Fehlermeldung (rot).
//   Field { label: "Neues Kennwort"; hint: "mindestens 8 Zeichen"
//           Input { width: parent.width; echoMode: TextInput.Password } }
Column {
    id: root

    property string label: ""
    property string hint: ""
    property string error: ""
    default property alias content: slot.data

    spacing: 6

    Label { visible: root.label !== ""; text: root.label }

    Item {
        id: slot
        width: parent.width
        implicitHeight: childrenRect.height
        height: implicitHeight
    }

    Text {
        visible: root.error !== "" || root.hint !== ""
        width: parent.width
        text: root.error || root.hint
        wrapMode: Text.Wrap
        color: root.error ? Theme.destructive : Theme.mutedForeground
        font.family: Theme.fontSans
        font.pixelSize: 12
    }
}
