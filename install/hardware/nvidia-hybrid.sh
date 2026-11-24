#!/bin/bash
# Laptop mit zwei Grafikkarten (z. B. HP ProBook 450 G6: Intel UHD 620 + NVIDIA MX130):
# Das Bild macht die eingebaute Grafik. nouveau stürzt auf solchen Geräten beim Laden ab
# (Kernel-Oops in udev-worker, danach hängt Start und Herunterfahren) – also nouveau aus.
# Die NVIDIA-Karte bleibt ungenutzt und schläft (spart Akku).
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

if ! gpu_hybrid_nvidia; then
    rm -f /etc/limine-entry-tool.d/50-nvidia-hybrid.conf /etc/modprobe.d/etude-nouveau.conf
    exit 0
fi
cat > /etc/modprobe.d/etude-nouveau.conf <<CONF
# Etude: NVIDIA-Grafik neben Intel/AMD – nouveau abgeschaltet (install/hardware/nvidia-hybrid.sh)
blacklist nouveau
options nouveau modeset=0
CONF
rm -f /etc/modprobe.d/blacklist-nouveau.conf      # alter Name (Installer bis ISO v4)
limine_dropin 50-nvidia-hybrid 'KERNEL_CMDLINE[default]+=" modprobe.blacklist=nouveau"'
log "NVIDIA neben eingebauter Grafik: nouveau aus"
