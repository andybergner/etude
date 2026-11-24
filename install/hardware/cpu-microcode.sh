#!/bin/bash
# Microcode-Updates für den Prozessor (landen über den mkinitcpio-Hook „microcode“ im Initramfs)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

if cpu_intel; then pkg_add intel-ucode; log "Intel-Prozessor"
elif cpu_amd; then pkg_add amd-ucode; log "AMD-Prozessor"
fi
