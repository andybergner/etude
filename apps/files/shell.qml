//@ pragma AppId com.etude.files
// Etude Explorer – Dateimanager (App-ID: com.etude.files)
// Start: etude-files [ordner]      z. B. etude-files ~/Downloads
// Läuft der Explorer schon, öffnet etude-files keinen zweiten, sondern holt dieses Fenster
// nach vorne (IPC "files open"); ein eigenes Fenster gibt es mit --new-window.
import Quickshell
import Quickshell.Io
import QtQuick
import Etude.Ui
import Etude.Services

ShellRoot {
    EtudeConfig { id: configSvc }

    Places { id: placesSvc }
    FileOps { id: opsSvc }
    AppManager { id: appsSvc; Component.onCompleted: refresh() }

    // qs ipc -n -p …/apps/files call files open ORDNER DATEI
    IpcHandler {
        target: "files"
        function open(path: string, select: string): void { content.openExternal(path, select) }
    }

    AppWindow {                      // FloatingWindow + Tastatur-Wurzel (Etude.Ui)
        id: win
        title: content.tr.t("files.windowTitle").arg(content.location === placesSvc.home ? content.tr.t("files.home") : (content.location.split("/").pop() || "/"))
        implicitWidth: 1100
        implicitHeight: 700
        color: "transparent"
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()

        FilesContent {
            id: content
            anchors.fill: parent
            focus: true
            places: placesSvc
            ops: opsSvc
            apps: appsSvc
            config: configSvc
            initialLocation: Quickshell.env("ETUDE_FILES_PATH") || Quickshell.env("HOME") || "/"
            initialSelect: Quickshell.env("ETUDE_FILES_SELECT") || ""
            onCloseWindow: Qt.quit()
        }
    }
}
