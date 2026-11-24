# Live-System: auf der ersten Konsole startet der Etude-Installer (wie bei archiso zuerst das Automatik-Skript)
~/.automated_script.sh
if [ "$(tty)" = "/dev/tty1" ] && [ -z "${ETUDE_NO_INSTALLER:-}" ]; then
    etude-install
fi
