#!/bin/bash
# Paketquellen für Updates nach der Installation. Bei einer Offline-Installation ist die
# Spiegelliste des Live-Systems leer (reflector braucht Netzwerk) – dann gilt der weltweite
# Arch-Spiegel, der automatisch einen Server in der Nähe wählt.
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

list=/etc/pacman.d/mirrorlist
if [ -f "$list" ] && grep -q '^[[:space:]]*Server' "$list"; then
    log "Spiegelliste vorhanden"
    exit 0
fi
{
    echo '# Etude: weltweiter Arch-Spiegel (wählt einen Server in der Nähe).'
    echo '# Schnellere Spiegel finden:  sudo reflector --country Germany --latest 10 --sort rate --save /etc/pacman.d/mirrorlist'
    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch'
    [ -f "$list" ] && cat "$list"
} > "$list.new"
mv "$list.new" "$list"
log "Spiegelliste: geo.mirror.pkgbuild.com"
