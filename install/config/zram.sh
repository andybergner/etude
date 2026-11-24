#!/bin/bash
# Komprimierter Arbeitsspeicher statt Auslagerungsdatei
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

cat > /etc/systemd/zram-generator.conf <<CONF
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
CONF
