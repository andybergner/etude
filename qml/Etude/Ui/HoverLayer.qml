import QtQuick

// Hover-/Auswahlfläche als eigene Ebene, die nur ein- und ausblendet.
// Statt die Hintergrundfarbe zu animieren (das mischt z. B. dunkles Grau mit
// halbdurchsichtigem Weiß und blitzt dabei hell auf), liegt die Fläche darüber
// und es wird nur die Deckkraft animiert.
//   Rectangle { color: Theme.card; HoverLayer { shown: mouse.containsMouse } }
Rectangle {
    property bool shown: false
    property real level: 1                    // z. B. 0.6 beim Drücken

    anchors.fill: parent
    radius: parent && parent.radius !== undefined ? parent.radius : Theme.radiusMd
    color: Theme.accent
    opacity: shown ? level : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
}
