pragma Singleton
import QtQuick
import Quickshell

// Rückmeldungen als Benachrichtigung statt als Text in der Seite (wie Windows-Toasts):
//   Notify.success(tr.t("account.created").arg(name))
//   Notify.error(tr.t("…"), details)   Notify.info(…)   Notify.message(…)
// Drei Stufen wie im freedesktop-Standard: error = kritisch (ⓧ), info = niedrig (ⓘ),
// success/message = normal (ohne Symbol).
// app/icon: Absendername und Icon (Standard: Name der App aus Qt.application bzw. "Etude").
QtObject {
    id: root

    property string app: Qt.application.displayName || Qt.application.name || "Etude"
    property string icon: ""

    function send(kind, title, body) {
        const args = ["notify-send", "-a", root.app]
        if (root.icon) args.push("-i", root.icon)
        if (kind === "error") args.push("-u", "critical")
        else if (kind === "info") args.push("-u", "low")
        else args.push("-u", "normal")
        args.push("--", String(title || ""), String(body || ""))
        Quickshell.execDetached(args)
    }
    function success(title, body) { send("success", title, body) }
    function error(title, body) { send("error", title, body) }
    function info(title, body) { send("info", title, body) }
    function message(title, body) { send("normal", title, body) }
}
