#!/bin/bash
# Administratoren = Gruppe wheel (sudo). root bekommt kein Kennwort (gesperrt).
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

mkdir -p /etc/sudoers.d
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
passwd -l root >/dev/null
