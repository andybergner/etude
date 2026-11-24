#!/bin/bash
# Intel-Grafik: Vulkan und Videobeschleunigung (Broadwell und neuer: intel-media-driver,
# ältere: libva-intel-driver)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

gpu_intel || exit 0
pkg_add vulkan-intel
model=$(cpu_model); model=${model:-0}
if cpu_intel && (( model > 0 && model < 61 )); then
    pkg_add libva-intel-driver
    log "Intel-Grafik (ältere Generation)"
else
    pkg_add intel-media-driver libvpl vpl-gpu-rt
    log "Intel-Grafik"
fi
