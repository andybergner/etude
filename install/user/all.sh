#!/bin/bash
# Einrichtung pro Benutzer – läuft als der neue Benutzer (runuser). Alles Weitere
# (Theme, Hintergrund, Hyprland) erledigt etude-setup beim ersten Anmelden.
set -uo pipefail
. "$(dirname "$0")/../helpers/common.sh"
for part in folders; do   # weitere Schritte hier anhängen
    run_part "$ETUDE_INSTALL/user/$part.sh" 0
done
