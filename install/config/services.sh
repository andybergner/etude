#!/bin/bash
# Grunddienste (Bluetooth, Energiemodus und Anmeldebildschirm aktiviert das Paket etude selbst)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

systemctl enable NetworkManager.service systemd-timesyncd.service fstrim.timer
