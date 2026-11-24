import QtQuick
import Quickshell
import Quickshell.Services.Greetd

// Anmeldung über greetd – dieselbe Schnittstelle wie LockContext (für LockSurface):
// password, checking, failed, failCount, showLogin, submit(), errorText
Scope {
    id: root

    property string user: ""             // Anmeldename (z. B. "andy")
    property string password: ""
    property bool checking: false
    property bool failed: false
    property int failCount: 0
    property bool showLogin: false
    property string errorText: ""        // "" = Standardtext „Kennwort falsch“

    // Was nach der Anmeldung startet
    property var command: ["etude-session"]
    property var environment: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Etude"]   // XDG_CURRENT_DESKTOP setzt Hyprland selbst

    signal loggedIn(string user)

    function submit() {
        if (checking || password === "" || user === "") return
        failed = false
        errorText = ""
        checking = true
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
        Greetd.createSession(user)
    }
    function reset() {
        showLogin = false
        password = ""
        checking = false
        failed = false
        errorText = ""
    }
    function fail(msg) {
        checking = false
        password = ""
        failed = true
        errorText = msg || ""
        failCount++
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password)
            else if (error) root.errorText = message          // z. B. Fingerabdruck nicht erkannt
        }
        function onAuthFailure(message) { root.fail("") }   // falsches Kennwort → Standardtext
        function onReadyToLaunch() {
            root.loggedIn(root.user)
            Greetd.launch(root.command, root.environment)   // Quickshell beendet sich danach selbst
        }
        function onError(error) { root.fail(error) }
    }
}
