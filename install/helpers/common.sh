# shellcheck shell=bash
# Gemeinsame Funktionen für die Skripte unter install/ – wird von jedem Skript eingebunden:
#   . "$(dirname "$0")/../helpers/common.sh"
#
# Die Skripte laufen als root im installierten System (bei der Installation per arch-chroot,
# später auch direkt, z. B. nach einem Hardwarewechsel:  sudo bash /usr/share/etude/install/hardware/all.sh).
# Werte aus dem Installer stehen in $ETUDE_INSTALL/env (ETUDE_LOCALE, ETUDE_TZ, …). Fehlt ein Wert,
# lässt das betreffende Skript die Einstellung so, wie sie ist.

ETUDE_INSTALL=${ETUDE_INSTALL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
# Vorlagen (Limine, snapper …) liegen wie bei Omarchy in default/ neben install/
ETUDE_DEFAULTS=${ETUDE_DEFAULTS:-$(cd "$ETUDE_INSTALL/../default" 2>/dev/null && pwd)}
export ETUDE_INSTALL ETUDE_DEFAULTS
# shellcheck disable=SC1091
[ -f "$ETUDE_INSTALL/env" ] && . "$ETUDE_INSTALL/env"
ETUDE_PKG_QUEUE=${ETUDE_PKG_QUEUE:-/tmp/etude-install-packages}
export ETUDE_PKG_QUEUE

log()  { printf '    %s\n' "$*"; }
warn() { printf '    Warnung: %s\n' "$*"; }

# Teilskript ausführen. Mit strict=1 bricht ein Fehler das Ganze ab (config/), sonst nur Warnung (hardware/).
run_part() {
    local script=$1 strict=${2:-1}
    echo "--> ${script#"$ETUDE_INSTALL"/}"
    if bash "$script"; then return 0; fi
    if [ "$strict" = 1 ]; then echo "!! ${script##*/} fehlgeschlagen"; return 1; fi
    warn "${script##*/} fehlgeschlagen – wird übersprungen"
    return 0
}

# ---------- Hardware erkennen (über /sys, ohne lspci) ----------
# pci_has <Klassen-Präfix> <Hersteller>   z. B. pci_has 03 10de → NVIDIA-Grafik vorhanden
pci_has() {
    local d
    for d in /sys/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        [[ $(<"$d/class") == 0x$1* && $(<"$d/vendor") == "0x$2" ]] && return 0
    done
    return 1
}
gpu_intel()  { pci_has 03 8086; }
gpu_amd()    { pci_has 03 1002; }
gpu_nvidia() { pci_has 03 10de; }
# Laptop mit zwei Grafikkarten: NVIDIA plus eingebaute Intel/AMD-Grafik
gpu_hybrid_nvidia() { gpu_nvidia && { gpu_intel || gpu_amd; }; }

cpu_vendor() { awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo; }
cpu_intel()  { [ "$(cpu_vendor)" = GenuineIntel ]; }
cpu_amd()    { [ "$(cpu_vendor)" = AuthenticAMD ]; }
cpu_model()  { awk -F': ' '/^model[[:space:]]*:/ { print $2; exit }' /proc/cpuinfo; }
has_battery() { compgen -G '/sys/class/power_supply/BAT*' >/dev/null; }

# ---------- Pakete sammeln und einmal installieren ----------
pkg_add() { printf '%s\n' "$@" >> "$ETUDE_PKG_QUEUE"; }
pkg_flush() {
    [ -s "$ETUDE_PKG_QUEUE" ] || return 0
    local pkgs
    mapfile -t pkgs < <(sort -u "$ETUDE_PKG_QUEUE")
    log "Pakete: ${pkgs[*]}"
    # Offline-Installation: Pakete aus dem Repo der ISO (ETUDE_PACMAN_CONF setzt der Installer)
    pacman ${ETUDE_PACMAN_CONF:+--config "$ETUDE_PACMAN_CONF"} -S --needed --noconfirm "${pkgs[@]}" \
        && rm -f "$ETUDE_PKG_QUEUE"
}

# ---------- Kernel-Parameter für den Bootloader ----------
# Zusätze landen als Datei in /etc/limine-entry-tool.d/ – limine-entry-tool hängt sie an die
# Kernel-Zeile an (bei der Installation ohne das Tool liest config/limine.sh sie selbst).
#   limine_dropin nvidia-hybrid 'KERNEL_CMDLINE[default]+=" modprobe.blacklist=nouveau"'
limine_dropin() {
    mkdir -p /etc/limine-entry-tool.d
    printf '# Von Etude angelegt (install/)\n%s\n' "$2" > "/etc/limine-entry-tool.d/$1.conf"
    log "Bootparameter: /etc/limine-entry-tool.d/$1.conf"
}
