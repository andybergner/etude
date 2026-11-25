#!/bin/bash
# Grunddienste (den Anmeldebildschirm aktiviert das Paket etude selbst)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

systemctl enable NetworkManager.service systemd-timesyncd.service fstrim.timer
# Energiemodus und Bluetooth – macht das Paket etude auch, hier aber sicher bei jeder Installation
systemctl enable power-profiles-daemon.service
systemctl enable bluetooth.service
