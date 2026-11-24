#!/bin/sh
# Etude Update – Suchen und Installieren von Updates (Einstellungen › Etude Update)
#
#   update.sh check            Ohne Root: Updates suchen (checkupdates, eigene Paketliste in /tmp).
#                              Ausgabe:  U <paket> <alt> <neu>   je Update
#                                        E <paket>               Paket aus dem Etude-Repo
#   update.sh etude <pakete…>  Als Root (pkexec): nur diese Etude-Pakete aktualisieren.
#                              Brauchen sie neuere Systempakete, wird nichts installiert (Exit 3),
#                              denn Teil-Updates von Arch-Paketen gehen kaputt.
#   update.sh system           Als Root (pkexec): komplettes Systemupdate (pacman -Syu)
#
# Exit: 0 ok · 2 keine Updates (check) · 3 Systemupdate nötig · 4 pacman läuft schon · 1 Fehler
set -u
export LC_ALL=C

ETUDE_PKGS="etude etude-ui"
locked() { [ -e /var/lib/pacman/db.lck ]; }

case "${1:-}" in
check)
    command -v checkupdates >/dev/null 2>&1 || { echo "checkupdates is missing (package pacman-contrib)" >&2; exit 1; }
    out=$(checkupdates 2>&1); rc=$?
    # 0 = Updates, 2 = keine, sonst Fehler (z. B. kein Netz)
    if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then echo "$out" >&2; exit 1; fi
    # Pakete, die aus dem Etude-Repo kommen (auch künftige Apps)
    { pacman -Sl etude 2>/dev/null | awk '{print $2}'; printf '%s\n' $ETUDE_PKGS; } | sort -u | sed 's/^/E /'
    [ $rc -eq 2 ] && exit 2
    echo "$out" | awk 'NF >= 4 && $3 == "->" { print "U", $1, $2, $4 }'
    exit 0
    ;;
etude)
    shift
    [ $# -gt 0 ] || { echo "no packages" >&2; exit 1; }
    locked && { echo "pacman is already running" >&2; exit 4; }
    for p in "$@"; do case "$p" in *[!a-z0-9._+-]*) echo "invalid package name: $p" >&2; exit 1;; esac; done
    echo ">> pacman -Sy"
    pacman -Sy --noconfirm || exit 1
    # Was würde pacman mitinstallieren? Alles außer den gewünschten Paketen = Systemupdate nötig
    extra=$(pacman -Sp --needed --print-format '%n' "$@" 2>&1) || { echo "$extra" >&2; exit 1; }
    for p in "$@"; do extra=$(echo "$extra" | grep -vx "$p"); done
    if [ -n "$extra" ]; then
        echo "NEEDS_SYSTEM $(echo $extra)"
        exit 3
    fi
    echo ">> pacman -S $*"
    pacman -S --needed --noconfirm "$@" || exit 1
    ;;
system)
    locked && { echo "pacman is already running" >&2; exit 4; }
    echo ">> pacman -Syu"
    pacman -Syu --noconfirm || exit 1
    ;;
*)
    echo "usage: update.sh check | etude <packages…> | system" >&2
    exit 1
    ;;
esac
