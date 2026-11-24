#!/bin/bash
# Gerätename (ETUDE_HOSTNAME)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

[ -n "${ETUDE_HOSTNAME:-}" ] || exit 0
echo "$ETUDE_HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $ETUDE_HOSTNAME.localdomain $ETUDE_HOSTNAME
HOSTS
log "Gerätename: $ETUDE_HOSTNAME"
