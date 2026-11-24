#!/bin/bash
# Baut die Etude-ISO: archiso-Profil "releng" + Etude-Ergänzungen aus diesem Ordner.
# Braucht ein Arch-System mit archiso (sudo pacman -S archiso) und root.
#
#   sudo VERSION=0.1.0-alpha.1 iso/build.sh   → iso/out/etude-0.1.0-alpha.1-x86_64.iso
#   sudo iso/build.sh                         → iso/out/etude-dev.YYYYMMDD-x86_64.iso (Testbau)
#   OUT=/tmp/iso WORK=/var/tmp/w sudo iso/build.sh
#   OFFLINE=0 sudo iso/build.sh       ohne Offline-Repo (kleiner, Installation braucht Internet)
#
# Was dazukommt: Pakete (packages.x86_64), das [etude]-Repo (pacman-etude.conf), Dateien im
# Live-System (airootfs/), der Installer (etude-install) mit den Bausteinen aus install/,
# ein Offline-Repo mit allen Paketen (wie bei Omarchy: installieren ohne Netzwerk),
# NetworkManager statt iwd/networkd, Name und Bootmenü „Etude“.
set -euo pipefail

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
work=${WORK:-/var/tmp/etude-iso}
out=${OUT:-$here/out}
releng=/usr/share/archiso/configs/releng

[ "$(id -u)" = 0 ] || { echo "build.sh: bitte mit sudo starten" >&2; exit 1; }

# Version der ISO: 0.1.0, 0.1.0-alpha.1, 0.1.0-beta.2, 0.1.0-rc.1 (GitHub: aus dem Tag iso-v…)
version=${VERSION:-dev.$(date +%Y%m%d)}
[[ $version =~ ^([0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?|dev\.[0-9]+)$ ]] || {
    echo "build.sh: VERSION muss aussehen wie 0.1.0 oder 0.1.0-alpha.1 (ist: $version)" >&2; exit 1; }
echo ">> Etude-ISO $version"
[ -d "$releng" ] || { echo "build.sh: archiso fehlt (sudo pacman -S archiso)" >&2; exit 1; }

rm -rf "$work"
mkdir -p "$work" "$out"
p=$work/profile
cp -r "$releng" "$p"

# Pakete und Repo
grep -v '^#' "$here/packages.x86_64" | grep -v '^$' >> "$p/packages.x86_64"
cat "$here/pacman-etude.conf" >> "$p/pacman.conf"         # zum Bauen der ISO

# Dateien im Live-System + Installer
cp -r "$here/airootfs/." "$p/airootfs/"
install -Dm755 "$here/etude-install" "$p/airootfs/usr/local/bin/etude-install"
# Bausteine für das neue System (install/) und ihre Vorlagen (default/limine, default/snapper)
mkdir -p "$p/airootfs/usr/local/share/etude/default"
cp -r "$here/../install" "$p/airootfs/usr/local/share/etude/install"
cp -r "$here/../default/limine" "$here/../default/snapper" "$p/airootfs/usr/local/share/etude/default/"
install -Dm644 "$here/../branding/logo.txt" "$p/airootfs/usr/local/share/etude/logo.txt"
echo "$version" > "$p/airootfs/usr/local/share/etude/version"
# auch im Live-System: der Installer (pacstrap -P) übernimmt diese pacman.conf ins neue System
install -Dm644 "$p/pacman.conf" "$p/airootfs/etc/pacman.conf"
sed -i '/^file_permissions=(/a\  ["/usr/local/bin/etude-install"]="0:0:755"' "$p/profiledef.sh"

# Netzwerk: NetworkManager (nmcli/nmtui) statt iwd + systemd-networkd – die WLAN-Verbindung
# übernimmt der Installer ins neue System
wants=$p/airootfs/etc/systemd/system/multi-user.target.wants
rm -f "$wants/iwd.service" "$wants/systemd-networkd.service" \
      "$p/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" \
      "$p/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
mkdir -p "$wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$wants/NetworkManager.service"

# Name und Bootmenü
sed -i -e 's/^iso_name=.*/iso_name="etude"/' \
       -e "s/^iso_version=.*/iso_version=\"$version\"/" \
       -e 's/^iso_label=.*/iso_label="ETUDE_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' \
       -e 's|^iso_publisher=.*|iso_publisher="Etude <https://github.com/andybergner/etude>"|' \
       -e 's/^iso_application=.*/iso_application="Etude Installer"/' "$p/profiledef.sh"
grep -rl "Arch Linux install medium" "$p/efiboot" "$p/syslinux" "$p/grub" 2>/dev/null \
    | xargs -r sed -i 's/Arch Linux install medium/Etude installieren/g'
echo "etude-live" > "$p/airootfs/etc/hostname"

# ---------- Offline-Repo (wie Omarchy) ----------
# Alle Pakete aus install/*.packages samt Abhängigkeiten landen als lokales pacman-Repo im
# Live-System (/var/cache/etude/offline). Der Installer nimmt dann dieses Repo statt des Internets.
if [ "${OFFLINE:-1}" = 1 ]; then
    echo ">> Offline-Repo: Pakete laden"
    mirror=$p/airootfs/var/cache/etude/offline
    db=$work/offline-db                       # leere Paketdatenbank → pacman lädt alle Abhängigkeiten
    mkdir -p "$mirror" "$db"
    list() { grep -hv '^[[:space:]]*#' "$@" | awk 'NF { print $1 }' | sort -u; }
    pm() { pacman --config "$p/pacman.conf" --dbpath "$db" --cachedir "$mirror" --noconfirm "$@"; }
    pm -Sy >/dev/null
    mapfile -t need < <(list "$here/../install/etude-base.packages" "$here/../install/etude-hardware.packages")
    pm -Sw "${need[@]}"
    mapfile -t boot < <(list "$here/../install/etude-boot.packages")
    pm -Sw "${boot[@]}" || echo ">> Hinweis: Bootmenü-Pakete fehlen im [etude]-Repo (Action „aur“) – die ISO installiert dann ohne Schnappschüsse im Bootmenü" >&2
    rm -f "$mirror"/*.part
    repo-add -q "$mirror/offline.db.tar.gz" "$mirror"/*.pkg.tar.zst
    echo ">> Offline-Repo: $(find "$mirror" -name '*.pkg.tar.zst' | wc -l) Pakete, $(du -sh "$mirror" | cut -f1)"

    # pacman.conf für die Installation aus diesem Repo (Pakete ohne eigene Signaturdateien,
    # deshalb TrustAll – sie stammen aus den Arch-Spiegeln bzw. dem [etude]-Repo beim Bauen)
    mkdir -p "$p/airootfs/etc/etude"
    cat > "$p/airootfs/etc/etude/pacman-offline.conf" <<'CONF'
# Etude-ISO: Installation aus dem Offline-Repo (etude-install)
[options]
Architecture = auto
CheckSpace
SigLevel = Optional TrustAll
LocalFileSigLevel = Optional
CacheDir = /var/cache/etude/offline/

[offline]
Server = file:///var/cache/etude/offline
CONF
fi

mkarchiso -v -w "$work/work" -o "$out" "$p"
ls -lh "$out"/*.iso
