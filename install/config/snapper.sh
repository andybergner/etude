#!/bin/bash
# snapper: Schnappschuss vor und nach jedem Update (snap-pac), 5 behalten, keine stündlichen.
# Die Konfiguration „root“ legt der Installer an (braucht ein leeres /.snapshots); hier kommen
# nur die Etude-Werte hinein – geht auch nachträglich.
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

conf=/etc/snapper/configs/root
if [ ! -f "$conf" ]; then
    warn "snapper ist nicht eingerichtet ($conf fehlt) – übersprungen"
    exit 0
fi
while IFS='=' read -r key value; do
    [[ $key =~ ^[A-Z_]+$ ]] || continue
    if grep -q "^$key=" "$conf"; then sed -i "s|^$key=.*|$key=$value|" "$conf"
    else echo "$key=$value" >> "$conf"; fi
done < "$ETUDE_DEFAULTS/snapper/root"

mkdir -p /etc/conf.d
echo 'SNAPPER_CONFIGS="root"' > /etc/conf.d/snapper
systemctl disable snapper-timeline.timer >/dev/null 2>&1 || true
systemctl enable snapper-cleanup.timer
log "snapper: 5 Schnappschüsse, nur bei Updates"
