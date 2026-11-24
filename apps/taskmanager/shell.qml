//@ pragma AppId com.etude.taskmanager
// Etude Task-Manager – eigenes Fenster, eigener Prozess (App-ID: com.etude.taskmanager)
// Start: etude-taskmanager [seite]   z. B. etude-taskmanager performance
// Läuft schon eine Instanz, holt etude-taskmanager nur das Fenster nach vorne (IPC).
import Quickshell
import Quickshell.Io
import QtQuick
import Etude.Ui
import Etude.Services

ShellRoot {
    id: shellRoot
    property Translations tr: Translations { domain: "taskmanager" }   // Texte der App

    readonly property string appId: "com.etude.taskmanager"

    System { id: systemSvc; running: win.visible }
    Services { id: servicesSvc }
    AppManager { id: appsSvc }

    AppWindow {                      // FloatingWindow + Tastatur-Wurzel (Etude.Ui)
        id: win
        title: tr.t("tm.taskManager")
        implicitWidth: 1080
        implicitHeight: 720
        color: "transparent"
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()

        TaskManagerContent {
            id: content
            anchors.fill: parent
            focus: true
            sys: systemSvc
            services: servicesSvc
            apps: appsSvc
            page: Quickshell.env("ETUDE_TASKMANAGER_PAGE") || "processes"
        }
    }

    IpcHandler {
        target: "taskmanager"
        function open(page: string): void { content.open(page) }
    }
}
