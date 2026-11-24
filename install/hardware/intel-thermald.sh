#!/bin/bash
# thermald hält Intel-Laptops kühl und leise (Sandy Bridge und neuer; nicht auf ThinkPads
# mit DYTC, dort verweigert thermald den Dienst)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

cpu_intel && has_battery || exit 0
[ -e /sys/devices/platform/thinkpad_acpi/dytc_lapmode ] && exit 0
model=$(cpu_model)
(( ${model:-0} >= 42 )) || exit 0
pkg_add thermald
# Dienst erst nach der Installation des Pakets aktivieren (pkg_flush läuft am Ende von all.sh)
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/thermald.service /etc/systemd/system/multi-user.target.wants/thermald.service
log "thermald (Intel-Laptop)"
