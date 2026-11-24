#!/bin/bash
# AMD-Grafik: Vulkan (Videobeschleunigung steckt in mesa)
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

gpu_amd || exit 0
pkg_add vulkan-radeon
log "AMD-Grafik"
