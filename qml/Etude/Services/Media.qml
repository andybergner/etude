import QtQuick
import Quickshell.Services.Mpris

// Laufende Wiedergabe über MPRIS (Spotify, Firefox, mpv, …)
Item {
    // bevorzugt den Player, der gerade spielt
    readonly property var player: {
        const list = Mpris.players ? Mpris.players.values : []
        return list.find(p => p.isPlaying) || list[0] || null
    }
    readonly property bool active: player !== null && (player.trackTitle || "") !== ""
    readonly property string app: player ? (player.identity || "") : ""
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: player ? player.isPlaying : false

    function previous() { if (player && player.canGoPrevious) player.previous() }
    function playPause() { if (player) player.togglePlaying() }
    function next() { if (player && player.canGoNext) player.next() }
}
