import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Eigenes Benutzerkonto: Name, Profilbild, Kennwort – über AccountsService (D-Bus)
// und ~/.face (Profilbild, das Lockscreen, Startmenü und Einstellungen anzeigen).
Item {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER") || ""
    readonly property string facePath: home + "/.face"

    property string realName: ""
    property int uid: 0
    property bool isAdmin: false
    property bool hasAccountsService: false
    property var users: []               // [{ name, realName, uid, admin }]
    property int faceVersion: 0          // erhöhen = Bild neu laden
    property bool hasFace: false

    property string error: ""
    property string message: ""
    property bool busy: false

    readonly property string displayName: realName || user
    readonly property string userPath: "/org/freedesktop/Accounts/User" + uid

    function refresh() { infoProc.running = true; usersProc.running = true; faceCheck.running = true }

    // ---- Daten lesen ----
    Process {
        id: infoProc
        command: ["sh", "-c",
            "echo \"uid=$(id -u)\"; echo \"groups=$(id -nG)\";" +
            "echo \"name=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1)\";" +
            "busctl status org.freedesktop.Accounts >/dev/null 2>&1 && echo accounts=1 || echo accounts=0"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of this.text.split("\n")) {
                    const i = l.indexOf("="); if (i < 0) continue
                    const k = l.slice(0, i), v = l.slice(i + 1)
                    if (k === "uid") root.uid = parseInt(v)
                    if (k === "groups") root.isAdmin = v.split(" ").indexOf("wheel") >= 0
                    if (k === "name") root.realName = v
                    if (k === "accounts") root.hasAccountsService = v === "1"
                }
            }
        }
    }
    Process {
        id: usersProc
        // Name:UID:Voller Name:Administrator (Mitglied von wheel)
        command: ["sh", "-c", "w=\",$(getent group wheel | cut -d: -f4),\"; " +
            "getent passwd | awk -F: -v w=\"$w\" '$3>=1000 && $3<60000 {split($5,g,\",\"); a = index(w, \",\" $1 \",\") ? 1 : 0; print $1\":\"$3\":\"g[1]\":\"a}'"]
        stdout: StdioCollector {
            onStreamFinished: root.users = this.text.split("\n").filter(l => l).map(l => {
                const f = l.split(":")
                return { name: f[0], uid: parseInt(f[1]), realName: f[2] || "", admin: f[3] === "1" }
            })
        }
    }
    Process {
        id: faceCheck
        command: ["test", "-f", root.facePath]
        onExited: (code) => { root.hasFace = code === 0; root.faceVersion++ }
    }

    // ---- Ausführen mit Fehlermeldung ----
    Process {
        id: run
        property string okMessage: ""
        stderr: StdioCollector { id: runErr }
        onExited: (code) => {
            root.busy = false
            // Erfolg als Benachrichtigung (Notify), Fehler bleiben in der Seite neben dem Formular
            if (code === 0) { root.error = ""; root.message = okMessage; if (okMessage) Notify.success(okMessage) }
            else root.error = /dismissed|cancel/i.test(runErr.text) ? ""          // "Nein" in der Benutzerkontensteuerung
                : /not authorized|polkit|interactive|denied/i.test(runErr.text)
                ? tr.t("account.noPermissionCancelledOrThe")
                : (runErr.text.trim() || tr.t("account.failed"))
            root.refresh()
        }
    }
    function exec(cmd, ok) {
        error = ""; message = ""; busy = true
        run.okMessage = ok
        run.command = cmd
        run.running = true
    }

    // Name: AccountsService (schreibt /etc/passwd)
    function setRealName(name) {
        name = name.trim().replace(/[:,\n]/g, "")
        if (!hasAccountsService) { error = tr.t("account.accountsserviceIsMissingSudoPacman"); return }
        exec(["busctl", "call", "org.freedesktop.Accounts", userPath,
              "org.freedesktop.Accounts.User", "SetRealName", "s", name], tr.t("account.nameSaved"))
    }

    // Profilbild: nach ~/.face kopieren (+ AccountsService, falls vorhanden – z. B. für den Anmeldebildschirm)
    function setAvatar(path) {
        let cmd = "cp -f -- \"$1\" \"$HOME/.face\" && chmod 644 \"$HOME/.face\""
        if (hasAccountsService)
            cmd += " && busctl call org.freedesktop.Accounts " + userPath
                 + " org.freedesktop.Accounts.User SetIconFile s \"$HOME/.face\" || true"
        exec(["sh", "-c", cmd, "sh", path], tr.t("account.profilePictureChanged"))
    }
    function removeAvatar() {
        exec(["sh", "-c", "rm -f \"$HOME/.face\""], tr.t("account.profilePictureRemoved"))
    }

    // Kennwort ändern: altes Kennwort per PAM prüfen, neues als Hash an AccountsService
    property string _newPassword: ""
    function changePassword(oldPw, newPw) {
        error = ""; message = ""
        if (!hasAccountsService) { error = tr.t("account.accountsserviceIsMissingSudoPacman"); return }
        if (newPw.length < 8) { error = tr.t("account.theNewPasswordMustHave"); return }
        busy = true
        _newPassword = newPw
        pam.oldPw = oldPw
        pam.start()
    }
    PamContext {
        id: pam
        property string oldPw: ""
        onPamMessage: if (this.responseRequired) this.respond(oldPw)
        onCompleted: (result) => {
            oldPw = ""
            if (result === PamResult.Success) {
                hashProc.stdinEnabled = true
                hashProc.running = true
            } else {
                root.busy = false
                root._newPassword = ""
                root.error = tr.t("account.theCurrentPasswordIsIncorrect")
            }
        }
    }
    // Hash erzeugen (Kennwort über stdin, nicht in der Befehlszeile)
    Process {
        id: hashProc
        command: ["openssl", "passwd", "-6", "-stdin"]
        stdinEnabled: true
        onStarted: { write(root._newPassword + "\n"); root._newPassword = ""; stdinEnabled = false }
        stdout: StdioCollector {
            onStreamFinished: {
                const hash = this.text.trim()
                if (!hash.startsWith("$6$")) { root.busy = false; root.error = tr.t("account.thePasswordCouldNotBe"); return }
                root.exec(["busctl", "call", "org.freedesktop.Accounts", root.userPath,
                           "org.freedesktop.Accounts.User", "SetPassword", "ss", hash, ""], tr.t("account.passwordChanged"))
            }
        }
    }

    // ---- Andere Benutzer (AccountsService; polkit fragt über die Benutzerkontensteuerung) ----
    function validUserName(n) { return /^[a-z_][a-z0-9_-]{0,31}$/.test(n) }

    property var _newUser: null          // { name, full, admin, pw }
    function createUser(name, full, pw, admin) {
        error = ""; message = ""
        if (!hasAccountsService) { error = tr.t("account.accountsserviceIsMissingSudoPacman"); return }
        if (!validUserName(name)) { error = tr.t("account.invalidUserName"); return }
        if (users.some(u => u.name === name)) { error = tr.t("account.thatUserNameAlreadyExists"); return }
        if (pw.length < 8) { error = tr.t("account.thePasswordMustHaveAt"); return }
        busy = true
        _newUser = { name: name, full: full.trim().replace(/[:,\n]/g, ""), admin: admin }
        newHash.pw = pw
        newHash.running = true
    }
    Process {
        id: newHash
        property string pw: ""
        command: ["openssl", "passwd", "-6", "-stdin"]
        stdinEnabled: true
        onStarted: { write(pw + "\n"); pw = ""; stdinEnabled = false }
        onExited: stdinEnabled = true
        stdout: StdioCollector {
            onStreamFinished: {
                const hash = this.text.trim()
                const u = root._newUser
                root._newUser = null
                if (!u || !hash.startsWith("$6$")) { root.busy = false; root.error = tr.t("account.thePasswordCouldNotBe"); return }
                // CreateUser liefert den Objektpfad des neuen Kontos, dann Kennwort setzen
                root.exec(["sh", "-c",
                    "p=$(busctl call org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts " +
                    "CreateUser ssi \"$1\" \"$2\" \"$3\" | awk '{print $2}' | tr -d '\"') && [ -n \"$p\" ] && " +
                    "busctl call org.freedesktop.Accounts \"$p\" org.freedesktop.Accounts.User SetPassword ss \"$4\" ''",
                    "sh", u.name, u.full, u.admin ? "1" : "0", hash], tr.t("account.created").arg(u.name))
            }
        }
    }
    function setAdmin(u, admin) {
        exec(["busctl", "call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts/User" + u.uid,
              "org.freedesktop.Accounts.User", "SetAccountType", "i", admin ? "1" : "0"],
             tr.t(admin ? "account.nowAdmin" : "account.nowStandard").arg(u.realName || u.name))
    }
    function deleteUser(u, removeFiles) {
        if (u.name === user) { error = tr.t("account.youCantRemoveYourOwn"); return }
        exec(["busctl", "call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts",
              "org.freedesktop.Accounts", "DeleteUser", "xb", String(u.uid), removeFiles ? "true" : "false"],
             tr.t("account.removed").arg(u.name))
    }

    Component.onCompleted: refresh()
}
