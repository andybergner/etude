pragma Singleton
import QtQuick
import Quickshell

// Sprache von Etude = Sprache des Systems. Gelesen aus ~/.config/locale.conf (falls vorhanden)
// bzw. /etc/locale.conf – dort schreibt Einstellungen › Zeit & Sprache (localectl) hin –, sonst
// aus $LC_ALL/$LC_MESSAGES/$LANG. Die Dateien werden beobachtet: ein Wechsel der Systemsprache
// wirkt in Etude sofort. Gibt es für die Sprache keine Übersetzung, gilt Englisch (je Text).
//
// Gemeinsame Texte (OK, Abbrechen, …) liegen in default/i18n/<sprache>/ui.json und gehen direkt über
// I18n.t("common.cancel"). Module bringen ihre eigenen Texte mit, siehe Translations.qml.
// Datum, Uhrzeit und Zahlen: I18n.locale statt Qt.locale("…"), I18n.formatNumber(x).
QtObject {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    // Systemsprache, z. B. "de_DE.UTF-8" (Nutzer-Datei vor System-Datei vor Umgebung)
    readonly property string systemLocale: {
        const fromFile = (text) => {
            const vars = {}
            for (const line of String(text || "").split("\n")) {
                const m = /^\s*(LANG|LC_MESSAGES|LC_ALL)\s*=\s*"?([^"\s]+)"?/.exec(line)
                if (m) vars[m[1]] = m[2]
            }
            return vars.LC_ALL || vars.LC_MESSAGES || vars.LANG || ""
        }
        const v = Quickshell.env("LC_ALL") || fromFile(userConf.text) || fromFile(systemConf.text)
                  || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || ""
        return v === "C" || v === "POSIX" || v.startsWith("C.") ? "en_US" : v
    }
    // Sprachcode für die Kataloge: "de", "nl", "pt-BR" (Region nur, wenn angegeben)
    readonly property string language: {
        const m = /^([a-z]{2,3})(?:_([A-Z]{2}))?/.exec(systemLocale)
        return m ? (m[2] ? m[1] + "-" + m[2] : m[1]) : "en"
    }
    readonly property var locale: Qt.locale(systemLocale.split(".")[0] || "en_US")
    readonly property bool rightToLeft: locale.textDirection === Qt.RightToLeft

    // gemeinsame Texte
    function t(key, fallback) { return common.t(key, fallback) }
    function tn(key, count, fallback) { return common.tn(key, count, fallback) }

    // Zahl mit dem Dezimaltrennzeichen der Sprache (ohne Tausendertrennung)
    function formatNumber(value, decimals) {
        const s = decimals !== undefined ? Number(value).toFixed(decimals) : String(value)
        return locale.decimalPoint === "." ? s : s.replace(".", locale.decimalPoint)
    }

    property Translations common: Translations { domain: "ui"; language: root.language }
    property WatchedFile userConf: WatchedFile { path: root.configHome + "/locale.conf" }
    property WatchedFile systemConf: WatchedFile { path: "/etc/locale.conf" }
}
