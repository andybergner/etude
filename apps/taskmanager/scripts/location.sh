#!/bin/sh
# Speicherort eines Prozesses für „Dateispeicherort öffnen“. Aufruf: location.sh PID
# Normalerweise die Programmdatei (/proc/PID/exe). Bei Quickshell-Apps (qs/quickshell, z. B. die
# Etude-Apps Explorer, Einstellungen, Task-Manager und die Shell selbst) ist das Programm aber
# immer qs – dann wird stattdessen die App gezeigt: ihre shell.qml im Ordner aus "qs -p ORDNER".
pid=$1
p=$(readlink -f "/proc/$pid/exe" 2>/dev/null); p=${p% (deleted)}
if [ ! -e "$p" ]; then
    c=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | head -n1)
    case "$c" in /*) p=$c ;; *) p=$(command -v "$c" 2>/dev/null) ;; esac
fi
case "${p##*/}" in
qs|quickshell)
    cfg=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | awk '
        f { print; exit }
        $0 == "-p" || $0 == "--path" { f = 1; next }
        /^--path=/ { sub(/^--path=/, ""); print; exit }')
    [ -z "$cfg" ] && cfg=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^QS_CONFIG_PATH=//p' | head -n1)
    [ -z "$cfg" ] && cfg="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
    # relativer Pfad → zum Arbeitsordner des Prozesses
    case "$cfg" in /*) ;; *) cfg="$(readlink -f "/proc/$pid/cwd" 2>/dev/null)/$cfg" ;; esac
    [ -d "$cfg" ] && cfg="$cfg/shell.qml"
    [ -e "$cfg" ] && p=$cfg
    ;;
esac
[ -e "$p" ] && readlink -f -- "$p"
