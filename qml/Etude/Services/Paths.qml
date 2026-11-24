pragma Singleton
import QtQuick
import Quickshell

// Wo Etude liegt und wohin Nutzerdaten gehören.
//   home    Programmdateien (nur lesen): ETUDE_HOME – Paket /usr/share/etude, Entwicklung das Repo
//   config  Einstellungen               ~/.config/etude
//   data    eigene Daten (Hintergründe) ~/.local/share/etude
//   state   Verlauf, Zustände           ~/.local/state/etude
//   cache   Zwischenspeicher            ~/.cache/etude
// Etude-Programme (etude-settings, etude-files, …) über ihren Namen starten – sie liegen im PATH.
QtObject {
    readonly property string userHome: Quickshell.env("HOME")
    readonly property string home: Quickshell.env("ETUDE_HOME") || "/usr/share/etude"
    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || userHome + "/.config") + "/etude"
    readonly property string data: (Quickshell.env("XDG_DATA_HOME") || userHome + "/.local/share") + "/etude"
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || userHome + "/.local/state") + "/etude"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || userHome + "/.cache") + "/etude"
}
