#!/bin/bash
# Tastatur für Konsole (ETUDE_KEYMAP) und Hyprland/Anmeldebildschirm (ETUDE_XKB, ETUDE_XKB_VARIANT).
# hypr/etude/input.lua liest 00-keyboard.conf.
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

[ -n "${ETUDE_KEYMAP:-}" ] && echo "KEYMAP=$ETUDE_KEYMAP" > /etc/vconsole.conf
if [ -n "${ETUDE_XKB:-}" ]; then
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<CONF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$ETUDE_XKB"
    Option "XkbVariant" "${ETUDE_XKB_VARIANT:-}"
EndSection
CONF
    log "Tastatur: $ETUDE_XKB${ETUDE_XKB_VARIANT:+ ($ETUDE_XKB_VARIANT)}"
fi
