#!/bin/bash
# Zeitzone und Sprache (ETUDE_TZ, ETUDE_LOCALE)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

if [ -n "${ETUDE_TZ:-}" ]; then
    ln -sf "/usr/share/zoneinfo/$ETUDE_TZ" /etc/localtime
    hwclock --systohc || true
    log "Zeitzone: $ETUDE_TZ"
fi
if [ -n "${ETUDE_LOCALE:-}" ]; then
    # Deutsch und Englisch immer erzeugen (Etude kann zwischen beiden umschalten)
    for l in de_DE.UTF-8 en_US.UTF-8 "$ETUDE_LOCALE"; do
        sed -i "s/^#\(${l//./\\.} UTF-8\)/\1/" /etc/locale.gen
    done
    locale-gen
    echo "LANG=$ETUDE_LOCALE" > /etc/locale.conf
    log "Sprache: $ETUDE_LOCALE"
fi
