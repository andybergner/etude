#!/bin/sh
# Neues Release: Version im PKGBUILD setzen, committen, taggen, pushen.
# GitHub Actions baut daraufhin das Paket und legt es ins Pacman-Repo (Release "repo").
#
#   scripts/release.sh ui 0.1.0-alpha.1      -> etude-ui 0.1.0alpha1, Tag ui-v0.1.0-alpha.1
#   scripts/release.sh etude 0.1.0-beta.2    -> etude 0.1.0beta2,     Tag etude-v0.1.0-beta.2
#   scripts/release.sh etude 0.1.0           -> etude 0.1.0,          Tag etude-v0.1.0
#   scripts/release.sh etude 0.1.0 2         -> nur neues pkgrel (Paket neu gebaut, Code gleich)
#
# Vorabversionen: -alpha.N, -beta.N, -rc.N. pacman erlaubt keinen Bindestrich in pkgver,
# deshalb wird daraus 0.1.0alpha1 – pacman sortiert richtig:
#   0.1.0alpha1 < 0.1.0alpha2 < 0.1.0beta1 < 0.1.0rc1 < 0.1.0 < 0.1.1
set -eu
cd "$(dirname "$0")/.."

case "${1:-}" in
    ui)    pkg=etude-ui; prefix=ui-v ;;
    etude) pkg=etude;    prefix=etude-v ;;
    *) echo "usage: scripts/release.sh <ui|etude> <version> [pkgrel]" >&2; exit 1 ;;
esac
ver=${2:?version missing (z. B. 0.1.0-alpha.1)}
rel=${3:-1}
echo "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$' || {
    echo "version must look like 1.2.3 or 1.2.3-alpha.1 / -beta.1 / -rc.1" >&2; exit 1; }
pkgver=$(printf '%s' "$ver" | sed -E 's/-(alpha|beta|rc)\./\1/')     # 0.1.0-alpha.1 → 0.1.0alpha1
tag="$prefix$ver"; [ "$rel" = 1 ] || tag="$tag-$rel"

[ -z "$(git status --porcelain)" ] || { echo "working tree not clean – commit first" >&2; exit 1; }
git rev-parse "$tag" >/dev/null 2>&1 && { echo "tag $tag already exists" >&2; exit 1; }

f="packaging/$pkg/PKGBUILD"
sed -i "s/^pkgver=.*/pkgver=$pkgver/; s/^pkgrel=.*/pkgrel=$rel/" "$f"
git add "$f"
git diff --cached --quiet || git commit -m "$pkg $ver ($pkgver-$rel)"     # Version stand schon drin: kein Commit nötig
git tag -a "$tag" -m "$pkg $ver ($pkgver-$rel)"
git push origin HEAD "$tag"
echo "Released $pkg $pkgver-$rel ($tag). Build: https://github.com/andybergner/etude/actions"
