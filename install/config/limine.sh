#!/bin/bash
# Bootloader Limine (UEFI) – nach dem Vorbild von Omarchy:
#   /etc/default/limine               aus default/limine/default.conf, @@CMDLINE@@ → Root-Partition
#   /etc/limine-entry-tool.d/*.conf   Etude-Vorgaben (00-etude.conf) und Zusätze aus hardware/
#   /boot/limine.conf                 nur Aussehen; die Einträge schreibt limine-update
#   limine-snapper-sync               Schnappschüsse im Bootmenü
# Ohne limine-mkinitcpio-hook (noch nicht im Repo) schreibt das Skript feste Einträge selbst –
# Etude startet dann genauso, nur ohne Schnappschüsse im Bootmenü.
#
# Nachträglich (z. B. nach Änderungen in /etc/limine-entry-tool.d):  sudo limine-update
# Ganz neu aufsetzen:  sudo bash /usr/share/etude/install/config/limine.sh
set -euo pipefail
. "$(dirname "$0")/../helpers/common.sh"

defaults=$ETUDE_DEFAULTS/limine
[ -f "$defaults/default.conf" ] || { echo "Vorlagen fehlen: $defaults"; exit 1; }
[ -d /boot/EFI ] || mkdir -p /boot/EFI
mountpoint -q /boot || warn "/boot ist keine eigene Partition – ist die EFI-Partition eingehängt?"

# ---------- Kernel-Zeile ----------
root_uuid=${ETUDE_ROOT_UUID:-$(findmnt -no UUID /)}
root_subvol=$(findmnt -no OPTIONS / | tr ',' '\n' | sed -n 's|^subvol=/\{0,1\}||p' | head -n1)
cmdline="root=UUID=$root_uuid rootflags=subvol=${root_subvol:-@} rw"
log "Root: $cmdline"

sed "s|@@CMDLINE@@|$cmdline|" "$defaults/default.conf" > /etc/default/limine
install -Dm644 "$defaults/etude.conf" /etc/limine-entry-tool.d/00-etude.conf

# ---------- Limine selbst: Fallback-Pfad, den jedes UEFI findet ----------
install -Dm644 /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/99-etude-limine.hook <<'HOOK'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine

[Action]
Description = Limine-Bootloader auf der EFI-Partition aktualisieren
When = PostTransaction
Exec = /usr/bin/cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
HOOK
rm -f /etc/pacman.d/hooks/99-limine.hook          # alter Name (Installer bis ISO v4)

# Startdateien neu bauen (Tastatur, modprobe.d aus hardware/ gehören ins Initramfs)
mkinitcpio -P

# ---------- Einträge ----------
[ -f /boot/limine.conf ] && cp /boot/limine.conf /boot/limine.conf.bak
if command -v limine-update >/dev/null; then
    install -m644 "$defaults/limine.conf" /boot/limine.conf
    limine-update
    if command -v limine-snapper-sync >/dev/null; then
        systemctl enable limine-snapper-sync.service
        limine-snapper-sync || warn "limine-snapper-sync: noch keine Schnappschüsse"
        log "Schnappschüsse erscheinen im Bootmenü"
    fi
else
    warn "limine-mkinitcpio-hook fehlt – feste Einträge, keine Schnappschüsse im Bootmenü"
    # Kernel-Zeile genau so zusammensetzen, wie limine-entry-tool es täte
    declare -A KERNEL_CMDLINE=()
    # shellcheck disable=SC1090
    for f in /etc/default/limine /etc/limine-entry-tool.d/*.conf; do [ -f "$f" ] && . "$f"; done
    full=${KERNEL_CMDLINE[default]# }
    rescue=$(sed -E 's/ (quiet|loglevel=[0-9]+|rd\.udev\.log_level=[0-9]+|systemd\.show_status=[a-z]+|vt\.global_cursor_default=0)//g' <<< " $full")
    {
        grep -v '^default_entry:' "$defaults/limine.conf"
        cat <<ENTRIES

/Etude
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $full
    module_path: boot():/initramfs-linux.img

/Etude (Notfall)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: ${rescue# }
    module_path: boot():/initramfs-linux-fallback.img
ENTRIES
    } > /boot/limine.conf
fi

# ---------- Eintrag im UEFI-Bootmenü ----------
if [ -n "${ETUDE_DISK:-}" ] && ! efibootmgr 2>/dev/null | grep -qE '^Boot[0-9A-F]{4}\*? Etude([[:space:]]|$)'; then
    efibootmgr --create --disk "$ETUDE_DISK" --part 1 --label Etude \
        --loader '\EFI\BOOT\BOOTX64.EFI' >/dev/null || warn "efibootmgr fehlgeschlagen (Fallback-Pfad bleibt)"
fi
log "Limine eingerichtet"
