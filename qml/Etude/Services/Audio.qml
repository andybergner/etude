import QtQuick
import Quickshell.Services.Pipewire

// Ton über PipeWire: Ausgabe (sink), Eingabe (source) und App-Lautstärken (Streams)
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : true

    // ---- Eingabe (Mikrofon) ----
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: source !== null && source.audio !== null
    readonly property real sourceVolume: sourceReady ? source.audio.volume : 0
    readonly property bool sourceMuted: sourceReady ? source.audio.muted : true

    // ---- Apps, die gerade Ton abspielen ----
    // Art über media.class bestimmen (isSink ist bei Streams nicht verlässlich: sonst zählte z. B. der
    // Benachrichtigungston (pw-play) als Aufnahme und das Mikrofon-Symbol erschien)
    function mediaClass(n) { return (n.properties && n.properties["media.class"]) || "" }
    readonly property var streamNodes: (Pipewire.nodes ? Pipewire.nodes.values : [])
        .filter(n => n.isStream && n.audio && root.mediaClass(n) === "Stream/Output/Audio")

    // ---- Apps, die gerade aufnehmen (Mikrofon) bzw. die Kamera über PipeWire nutzen ----
    readonly property var captureNodes: (Pipewire.nodes ? Pipewire.nodes.values : [])
        .filter(n => n.isStream && n.audio && root.mediaClass(n) === "Stream/Input/Audio"
                     && !(n.properties["stream.monitor"] === "true"))   // Pegelanzeigen (z. B. pavucontrol) sind keine Aufnahme
    readonly property var recording: captureNodes.map(n => ({
        id: n.id,
        name: n.properties["application.name"] || n.description || n.name,
        icon: n.properties["application.icon-name"] || ""
    }))
    readonly property var videoCapture: (Pipewire.nodes ? Pipewire.nodes.values : [])
        .filter(n => n.isStream && (n.properties["media.class"] || "") === "Stream/Input/Video")
        .map(n => ({ id: n.id, name: n.properties["application.name"] || n.description || n.name,
                     icon: n.properties["application.icon-name"] || "" }))

    // Ohne Tracker liefert PipeWire keine Live-Werte
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null).concat(root.streamNodes).concat(root.captureNodes)
    }

    readonly property var sources: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : []
        return nodes.filter(n => !n.isSink && !n.isStream && n.audio && !(n.name || "").endsWith(".monitor"))
            .map(n => ({
                id: n.id,
                name: n.description || n.nickName || n.name,
                active: root.source !== null && n.id === root.source.id
            }))
    }
    function selectSource(id) {
        const node = Pipewire.nodes.values.find(n => n.id === id)
        if (node) Pipewire.preferredDefaultAudioSource = node
    }
    function setSource(v) {
        if (!sourceReady) return
        source.audio.muted = false
        source.audio.volume = Math.max(0, Math.min(1, v))
    }
    function toggleSourceMute() {
        if (sourceReady) source.audio.muted = !source.audio.muted
    }

    // App-Lautstärken: [{ id, name, icon, volume, muted }]
    readonly property var streams: streamNodes.map(n => ({
        id: n.id,
        name: n.properties["application.name"] || n.description || n.name,
        icon: n.properties["application.icon-name"] || "",
        volume: n.audio.volume,
        muted: n.audio.muted
    }))
    function setStream(id, v) {
        const n = streamNodes.find(x => x.id === id)
        if (n) { n.audio.muted = false; n.audio.volume = Math.max(0, Math.min(1, v)) }
    }
    function toggleStreamMute(id) {
        const n = streamNodes.find(x => x.id === id)
        if (n) n.audio.muted = !n.audio.muted
    }

    // alle Ausgabegeräte (keine Streams einzelner Apps)
    readonly property var sinks: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : []
        return nodes.filter(n => n.isSink && !n.isStream && n.audio).map(n => {
            const name = n.description || n.nickName || n.name
            const low = name.toLowerCase()
            return {
                id: n.id,
                name: name,
                kind: /head|kopfh|airpods|buds/.test(low) ? "headphones" : /hdmi|displayport|monitor/.test(low) ? "monitor" : "speaker",
                active: root.sink !== null && n.id === root.sink.id
            }
        })
    }
    function select(id) {
        const node = Pipewire.nodes.values.find(n => n.id === id)
        if (node) Pipewire.preferredDefaultAudioSink = node
    }

    function toggleMute() {
        if (ready) sink.audio.muted = !sink.audio.muted
    }
    function set(v) {
        if (!ready) return
        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, v))
    }
    function change(step) {                 // z. B. +0.05 oder -0.05
        if (ready) sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + step))
    }
}
