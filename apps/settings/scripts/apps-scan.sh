#!/bin/sh
# Liest .desktop-Dateien für die Einstellungen (Apps, Autostart).
#   apps-scan.sh apps       installierte Apps (+ Paket, Größe, Installationsdatum)
#   apps-scan.sh autostart  Autostart-Einträge (Benutzer und System, nicht zusammengeführt)
#   apps-scan.sh mime       Standard-Apps (mimeapps.list, Benutzer zuerst)
# Ausgabe: eine Zeile je Eintrag, Felder durch \037 (Unit Separator) getrennt.

mode=${1:-apps}
US=$(printf '\037')

entry() {   # $1 = Kennung (A/S), $2 = Datei
    awk -v tag="$1" -v path="$2" -v US="$US" '
        /^\[/ { sec = $0; next }
        sec != "[Desktop Entry]" { next }
        {
            i = index($0, "="); if (!i) next
            k = substr($0, 1, i - 1); v = substr($0, i + 1)
            sub(/[ \t]+$/, "", k); sub(/^[ \t]+/, "", v)
        }
        k == "Name"        { name = v }
        k == "Name[de]" || k == "Name[de_DE]"       { namede = v }
        k == "Comment"     { comment = v }
        k == "Comment[de]" || k == "Comment[de_DE]" { commentde = v }
        k == "Icon"        { icon = v }
        k == "Exec"        { exec = v }
        k == "Type"        { type = v }
        k == "NoDisplay"   { nodisplay = v }
        k == "Hidden"      { hidden = v }
        k == "MimeType"    { mime = v }
        k == "OnlyShowIn"  { only = v }
        k == "NotShowIn"   { notin = v }
        k == "Terminal"    { term = v }
        k == "X-Etude-Hidden" { ehidden = v }
        END {
            if (namede != "") name = namede
            if (commentde != "") comment = commentde
            n = split(path, p, "/"); id = p[n]
            print tag US id US path US name US icon US comment US exec US type US nodisplay US hidden US mime US only US notin US term US ehidden
        }' "$2"
}

case "$mode" in
apps)
    dirs="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    IFS=:; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs:$d/applications"; done; unset IFS
    seen=" "
    IFS=:; set -- $dirs; unset IFS
    for d in "$@"; do
        [ -d "$d" ] || continue
        for f in "$d"/*.desktop; do
            [ -f "$f" ] || continue
            id=${f##*/}
            case "$seen" in *" $id "*) continue ;; esac
            seen="$seen$id "
            entry A "$f"
        done
    done
    # Paket je .desktop-Datei direkt aus der pacman-Datenbank (schnell, ohne pacman aufzurufen)
    awk 'FNR == 1 { f = 0 } /^%FILES%$/ { f = 1; next } /^%/ { f = 0 }
         f && /^usr\/share\/applications\/[^\/]*\.desktop$/ { d = FILENAME; sub(/\/files$/, "", d); print "/" $0 "\t" d }' \
        /var/lib/pacman/local/*/files 2>/dev/null |
    while IFS="$(printf '\t')" read -r path dir; do
        awk -v path="$path" -v US="$US" '
            /^%NAME%$/        { getline; n = $0 }
            /^%SIZE%$/        { getline; s = $0 }
            /^%INSTALLDATE%$/ { getline; t = $0 }
            END { print "P" US path US n US s US t }' "$dir/desc"
    done
    ;;
autostart)
    dirs="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    IFS=:; for d in ${XDG_CONFIG_DIRS:-/etc/xdg}; do dirs="$dirs:$d/autostart"; done; unset IFS
    IFS=:; set -- $dirs; unset IFS
    first=1
    for d in "$@"; do
        tag=S; [ $first = 1 ] && tag=U; first=0
        [ -d "$d" ] || continue
        for f in "$d"/*.desktop; do [ -f "$f" ] && entry "$tag" "$f"; done
    done
    ;;
mime)
    for f in "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" /etc/xdg/mimeapps.list \
             "${XDG_DATA_HOME:-$HOME/.local/share}/applications/mimeapps.list" \
             /usr/local/share/applications/mimeapps.list /usr/share/applications/mimeapps.list; do
        echo "#FILE $f"
        [ -f "$f" ] && cat "$f"
    done
    ;;
esac
exit 0
