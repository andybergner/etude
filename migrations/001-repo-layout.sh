#!/bin/sh
# Umstieg von Testinstallationen vor 0.1.0: Aufbau nach Omarchy-Vorbild – share/ gibt es nicht mehr.
#   /usr/share/etude/share/wallpapers → /usr/share/etude/default/wallpapers
#   /usr/share/etude/hypr/etude       → /usr/share/etude/default/hypr  (Link setzt etude-setup neu)
# Gespeicherte Bildpfade in den Einstellungen und der Link ~/.config/etude/wallpaper werden umgestellt.
set -u
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

f="$CFG/etude/settings/appearance.json"
# nur die mitgelieferten Bilder (etude-logo-*.png) – eigene Ordner bleiben unangetastet
if [ -f "$f" ] && grep -q '/share/wallpapers/etude-logo-' "$f"; then
    sed -i 's#/share/wallpapers/etude-logo-#/default/wallpapers/etude-logo-#g' "$f"
fi

l="$CFG/etude/wallpaper"
if [ -L "$l" ]; then
    t=$(readlink "$l")
    case "$t" in
        */share/wallpapers/etude-logo-*) ln -sfn "$(printf '%s' "$t" | sed 's#/share/wallpapers/etude-logo-#/default/wallpapers/etude-logo-#')" "$l" ;;
    esac
fi
exit 0
