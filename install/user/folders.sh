#!/bin/bash
# Standardordner (Dokumente, Bilder, Downloads …) in der Systemsprache
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

[ -n "${ETUDE_LOCALE:-}" ] && export LANG=$ETUDE_LOCALE
xdg-user-dirs-update
log "Ordner in $HOME angelegt"
