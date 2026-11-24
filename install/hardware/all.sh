#!/bin/bash
# Hardware erkennen und anpassen. Jedes Skript prüft selbst, ob es zu diesem Computer passt.
# Pakete werden gesammelt und am Ende in einem Rutsch installiert. Ein fehlgeschlagener
# Fix bricht die Installation nicht ab (nur Warnung im Protokoll).
#
# Nachträglich, z. B. nach einem Hardwarewechsel:
#   sudo bash /usr/share/etude/install/hardware/all.sh && sudo limine-update
set -uo pipefail
. "$(dirname "$0")/../helpers/common.sh"
rm -f "$ETUDE_PKG_QUEUE"

for part in cpu-microcode intel-gpu amd-gpu nvidia-hybrid intel-thermald; do
    run_part "$ETUDE_INSTALL/hardware/$part.sh" 0
done

pkg_flush || { echo "!! Hardware-Pakete konnten nicht installiert werden"; exit 1; }
