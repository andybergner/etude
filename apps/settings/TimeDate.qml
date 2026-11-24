import QtQuick
import Etude.Ui
import Quickshell
import Quickshell.Io

// Zeit & Sprache: Zustand über timedatectl / localectl lesen und ändern
Item {
    id: root
    property Translations tr: Translations { domain: "settings" }   // Texte der App

    property string timezone: ""
    property bool ntp: true
    property var timezones: []
    property string locale: ""
    property var locales: []
    property string error: ""

    function refresh() { stateProc.running = true; localeProc.running = true }
    function loadLists() { tzListProc.running = true; localeListProc.running = true }

    function run(cmd) {
        error = ""
        setProc.command = cmd
        setProc.running = true
    }
    function setTimezone(tz) { timezone = tz; run(["timedatectl", "set-timezone", tz]) }
    function setNtp(on)      { ntp = on; run(["timedatectl", "set-ntp", on ? "true" : "false"]) }
    function setLocale(l)    { locale = l; run(["localectl", "set-locale", "LANG=" + l]) }

    Process {
        id: stateProc
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of this.text.split("\n")) {
                    if (l.startsWith("Timezone=")) root.timezone = l.slice(9)
                    if (l.startsWith("NTP=")) root.ntp = l.slice(4) === "yes"
                }
            }
        }
    }
    Process {
        id: localeProc
        command: ["sh", "-c", "localectl status | sed -n 's/.*LANG=\\([^ ]*\\).*/\\1/p' | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.locale = this.text.trim() }
    }
    Process {
        id: tzListProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: root.timezones = this.text.split("\n").filter(l => l) }
    }
    Process {
        id: localeListProc
        command: ["localectl", "list-locales"]
        stdout: StdioCollector { onStreamFinished: root.locales = this.text.split("\n").filter(l => l) }
    }
    Process {
        id: setProc
        stderr: StdioCollector { id: setErr }
        onExited: (code) => {
            if (code !== 0) root.error = /auth|polkit|interactive|denied/i.test(setErr.text)
                ? tr.t("time.noPermissionInstallThePolkit")
                : (setErr.text.trim() || tr.t("time.theChangeFailed"))
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
