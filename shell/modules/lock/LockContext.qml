import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Gemeinsamer Zustand für alle Monitore: Passwort, PAM-Prüfung, Fehler
Scope {
    id: root

    property string password: ""
    property bool checking: false
    property bool failed: false
    property int failCount: 0            // jedes Mal +1 → Oberfläche "wackelt"
    property bool showLogin: false       // false = Sperrbildschirm (Uhr), true = Anmeldung

    signal unlocked()

    function submit() {
        if (checking || password === "") return
        failed = false
        checking = true
        pam.start()
    }
    function reset() {
        showLogin = false
        password = ""
        checking = false
        failed = false
    }

    // Prüft das Passwort wie beim Login (PAM-Konfiguration "login")
    PamContext {
        id: pam
        onPamMessage: {
            if (this.responseRequired) this.respond(root.password)
        }
        onCompleted: (result) => {
            root.checking = false
            if (result === PamResult.Success) {
                root.reset()
                root.unlocked()
            } else {
                root.password = ""
                root.failed = true
                root.failCount++
            }
        }
    }
}
