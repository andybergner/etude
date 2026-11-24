#!/bin/sh
# Testbuild vor einem Release: baut die Pakete aus deinem Arbeitsstand (auch ohne Commit)
# und installiert sie – genau wie ein Release, nur lokal. So lassen sich auch Dinge testen,
# die erst als Paket wirken (Anmeldebildschirm/greetd, systemd-Dateien, polkit, etude-setup).
#
#   scripts/test-install.sh                 etude-ui und etude, Version aus den PKGBUILDs
#   scripts/test-install.sh 0.1.0-alpha.1   beide als 0.1.0alpha1 (die geplante Version)
#   scripts/test-install.sh etude 0.1.0     nur etude (bzw. ui)
#
# Version des Testbuilds: <version>-0.<datum><uhrzeit>, z. B. 0.1.0alpha1-0.202611241800.
# Das echte Release <version>-1 ist für pacman neuer – „Etude Update“ bietet es danach an.
# Zurück zum letzten Release: sudo pacman -Syuu  (installiert die Repo-Versionen)
set -eu
cd "$(dirname "$0")/.."
REPO=$(pwd)

which=all ver=""
case "${1:-}" in
    ui|etude) which=$1; ver=${2:-} ;;
    "") ;;
    *) ver=$1 ;;
esac
[ -z "$ver" ] || echo "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$' || {
    echo "version must look like 1.2.3 or 1.2.3-alpha.1 / -beta.1 / -rc.1" >&2; exit 1; }
ver=$(printf '%s' "$ver" | sed -E 's/-(alpha|beta|rc)\./\1/')     # 0.1.0-alpha.1 → 0.1.0alpha1
[ "$(id -u)" != 0 ] || { echo "run as your normal user (makepkg asks for sudo itself)" >&2; exit 1; }

rel="0.$(date +%Y%m%d%H%M)"
build() {
    pkg=$1
    work=$(mktemp -d "/tmp/etude-test-$pkg.XXXXXX")
    # nur PKGBUILD und .install – alte makepkg-Ordner (src/, pkg/) und Pakete bleiben liegen
    find "packaging/$pkg" -maxdepth 1 -type f \( -name PKGBUILD -o -name '*.install' \) -exec cp {} "$work/" \;
    [ -z "$ver" ] || sed -i "s/^pkgver=.*/pkgver=$ver/" "$work/PKGBUILD"
    sed -i "s/^pkgrel=.*/pkgrel=$rel/" "$work/PKGBUILD"
    v=$(sed -n 's/^pkgver=//p' "$work/PKGBUILD")
    echo ">> $pkg $v-$rel (Testbuild aus $REPO)"
    (cd "$work" && ETUDE_SRC="$REPO" makepkg -sfi --noconfirm --needed)
    rm -rf "$work"
}

case "$which" in
    all)   build etude-ui; build etude ;;
    ui)    build etude-ui ;;
    etude) build etude ;;
esac

echo
pacman -Q etude etude-ui 2>/dev/null || true
echo ">> Fertig. Dinge wie der Anmeldebildschirm wirken nach einem Neustart."
echo ">> Wenn alles passt: scripts/release.sh <ui|etude> <version>"
