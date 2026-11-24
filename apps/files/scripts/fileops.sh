#!/bin/sh
# Dateiaktionen für den Explorer. Aufruf: fileops.sh <befehl> [argumente …]
#   conflicts DEST SRC…               Namen, die es in DEST schon gibt
#   paste copy|move replace|skip|keep DEST SRC…
#                                     gibt aus: P␟GESAMTBYTES (nur wenn kopiert wird), I␟ZIEL (beginnt),
#                                     R␟QUELLE␟ZIEL (fertig, für Rückgängig); SIGTERM bricht ab
#   undomove ZIEL QUELLE …            Verschieben rückgängig machen
#   trash SRC…                        in den Papierkorb (freedesktop: ~/.local/share/Trash), gibt N␟NAME aus
#   trashlist                         NAME␟URSPRUNG␟DATUM␟ORDNER(0/1)␟GRÖSSE
#   restore NAME…   trashdelete NAME…   empty
#   delete SRC…                       endgültig löschen
#   mkdir DEST NAME   touch DEST NAME   neu anlegen (eindeutiger Name), gibt den Pfad aus
#   rename SRC NEUERNAME
#   props PFAD…                       Eigenschaften
#   info PFAD                         kurz für den Detailbereich: TYP␟GRÖSSE␟ERSTELLT␟GEÄNDERT␟MIME␟ANZAHL␟BESCHREIBUNG
#   preview PFAD                      Anfang einer Textdatei
#   compress DEST NAME SRC…           ZIP-Archiv anlegen (bsdtar), gibt den Pfad aus
#   extract ARCHIV here|folder        entpacken (hier oder in einen neuen Ordner), gibt die neuen Pfade aus
#   search ORDNER TEXT VERSTECKT(0/1) rekursiv suchen: TYP(d/f)␟GRÖSSE␟ZEIT␟PFAD (höchstens 2000)
# Meldungen übersetzen (default/i18n/<sprache>/files.json); ohne etude-i18n gilt der englische Text
t() {
    fb=$1; shift
    if command -v etude-i18n >/dev/null 2>&1; then etude-i18n -D files "$@"
    else k=$1; shift; i=1; for v in "$@"; do fb=$(printf '%s' "$fb" | sed "s|%$i|$v|g"); i=$((i+1)); done; printf '%s\n' "$fb"; fi
}

US=$(printf '\037')
TRASH="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"

# "name.ext" → "name (2).ext" … bis frei
unique() {
    dir=$1; name=$2
    [ -e "$dir/$name" ] || [ -L "$dir/$name" ] || { printf '%s' "$name"; return; }
    case "$name" in
        .*.*|[!.]*.*) base=${name%.*}; ext=".${name##*.}" ;;
        *) base=$name; ext="" ;;
    esac
    case "$name" in *.tar.gz|*.tar.xz|*.tar.zst|*.tar.bz2) base=${name%.tar.*}; ext=".tar.${name##*.tar.}" ;; esac
    n=2
    while [ -e "$dir/$base ($n)$ext" ] || [ -L "$dir/$base ($n)$ext" ]; do n=$((n + 1)); done
    printf '%s' "$base ($n)$ext"
}
# Prozent-Kodierung für .trashinfo (Spezifikation: Path= als URI-Pfad)
urlencode() {
    LC_ALL=C awk -v s="$1" 'BEGIN {
        for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i
        out = ""
        for (i = 1; i <= length(s); i++) {
            c = substr(s, i, 1)
            if (c ~ /[A-Za-z0-9\/._~-]/) out = out c; else out = out sprintf("%%%02X", ord[c])
        }
        printf "%s", out
    }'
}
urldecode() {
    LC_ALL=C awk -v s="$1" 'BEGIN {
        hex = "0123456789ABCDEF"; out = ""
        for (i = 1; i <= length(s); i++) {
            c = substr(s, i, 1)
            if (c == "%" && i + 2 <= length(s)) {
                h = toupper(substr(s, i + 1, 2))
                out = out sprintf("%c", (index(hex, substr(h, 1, 1)) - 1) * 16 + index(hex, substr(h, 2, 1)) - 1)
                i += 2
            } else out = out c
        }
        printf "%s", out
    }'
}

cmd=$1; shift
case "$cmd" in
conflicts)
    dest=$1; shift
    for s in "$@"; do n=${s##*/}; { [ -e "$dest/$n" ] || [ -L "$dest/$n" ]; } && [ "$s" != "$dest/$n" ] && echo "$n"; done
    ;;
paste)
    mode=$1; policy=$2; dest=$3; shift 3
    err=0; cur=""; cpid=""
    # Abbrechen: laufende Kopie beenden und das halbfertige Ziel entfernen
    trap '[ -n "$cpid" ] && kill "$cpid" 2>/dev/null; [ -n "$cpid" ] && wait "$cpid" 2>/dev/null; [ -n "$cur" ] && rm -rf -- "$cur"; exit 130' TERM INT
    # Fortschritt nur, wenn wirklich Daten kopiert werden (Verschieben im selben Dateisystem ist sofort fertig)
    need=0
    if [ "$mode" = copy ]; then need=1
    else ddev=$(stat -c %d -- "$dest" 2>/dev/null)
        for s in "$@"; do [ "$(stat -c %d -- "$s" 2>/dev/null)" = "$ddev" ] || need=1; done
    fi
    [ $need = 1 ] && printf 'P%s%s\n' "$US" "$(du -scb -- "$@" 2>/dev/null | tail -n1 | cut -f1)"
    for s in "$@"; do
        n=${s##*/}
        # nicht in sich selbst kopieren/verschieben
        case "$dest/" in "$s"/*) t "Skipped: “%1” can't be pasted into itself." files.errIntoItself "$n" >&2; err=1; continue ;; esac
        target="$dest/$n"
        if [ "$s" = "$target" ]; then
            [ "$mode" = move ] && continue
            target="$dest/$(unique "$dest" "$n")"
        elif [ -e "$target" ] || [ -L "$target" ]; then
            case "$policy" in
                skip) continue ;;
                keep) target="$dest/$(unique "$dest" "$n")" ;;
                replace) rm -rf -- "$target" || { err=1; continue; } ;;
            esac
        fi
        printf 'I%s%s\n' "$US" "$target"
        cur=$target
        if [ "$mode" = move ]; then mv -- "$s" "$target" & else cp -a -- "$s" "$target" & fi
        cpid=$!
        if wait "$cpid"; then printf 'R%s%s%s%s\n' "$US" "$s" "$US" "$target"; else err=1; fi
        cur=""; cpid=""
    done
    exit $err
    ;;
undomove)
    err=0
    while [ $# -ge 2 ]; do
        t=$1; s=$2; shift 2
        [ -e "$t" ] || [ -L "$t" ] || { err=1; continue; }
        if [ -e "$s" ] || [ -L "$s" ]; then t "“%1” already exists at its original location." files.errExistsOrigin "${s##*/}" >&2; err=1; continue; fi
        mkdir -p -- "$(dirname -- "$s")" && mv -- "$t" "$s" || err=1
    done
    exit $err
    ;;
trash)
    mkdir -p "$TRASH/files" "$TRASH/info" || exit 1
    err=0
    for s in "$@"; do
        abs=$(cd "$(dirname -- "$s")" && pwd)/${s##*/}
        n=$(unique "$TRASH/files" "${s##*/}")
        while [ -e "$TRASH/info/$n.trashinfo" ]; do n=$(unique "$TRASH/files" "$n.x"); done
        printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' "$(urlencode "$abs")" "$(date +%Y-%m-%dT%H:%M:%S)" > "$TRASH/info/$n.trashinfo"
        if mv -- "$s" "$TRASH/files/$n"; then printf 'N%s%s\n' "$US" "$n"; else rm -f "$TRASH/info/$n.trashinfo"; err=1; fi
    done
    exit $err
    ;;
trashlist)
    [ -d "$TRASH/info" ] || exit 0
    for i in "$TRASH/info"/*.trashinfo; do
        [ -f "$i" ] || continue
        n=${i##*/}; n=${n%.trashinfo}
        [ -e "$TRASH/files/$n" ] || [ -L "$TRASH/files/$n" ] || continue
        p=$(grep -m1 '^Path=' "$i" | cut -d= -f2-)
        d=$(grep -m1 '^DeletionDate=' "$i" | cut -d= -f2-)
        dir=0; [ -d "$TRASH/files/$n" ] && dir=1
        size=$(du -sb -- "$TRASH/files/$n" 2>/dev/null | cut -f1)
        printf '%s%s%s%s%s%s%s%s%s\n' "$n" "$US" "$(urldecode "$p")" "$US" "$d" "$US" "$dir" "$US" "${size:-0}"
    done
    ;;
restore)
    err=0
    for n in "$@"; do
        p=$(urldecode "$(grep -m1 '^Path=' "$TRASH/info/$n.trashinfo" | cut -d= -f2-)")
        [ -n "$p" ] || { err=1; continue; }
        dir=$(dirname -- "$p"); mkdir -p -- "$dir"
        target="$dir/$(unique "$dir" "${p##*/}")"
        mv -- "$TRASH/files/$n" "$target" && rm -f -- "$TRASH/info/$n.trashinfo" || err=1
    done
    exit $err
    ;;
trashdelete)
    for n in "$@"; do rm -rf -- "$TRASH/files/$n" && rm -f -- "$TRASH/info/$n.trashinfo"; done
    ;;
empty)
    rm -rf -- "$TRASH/files" "$TRASH/info" "$TRASH/directorysizes"; mkdir -p "$TRASH/files" "$TRASH/info"
    ;;
delete)
    rm -rf -- "$@"
    ;;
mkdir|touch)
    dest=$1; n=$(unique "$1" "$2")
    if [ "$cmd" = mkdir ]; then mkdir -- "$dest/$n"; else : > "$dest/$n"; fi && printf '%s\n' "$dest/$n"
    ;;
rename)
    src=$1; new=$2; dir=$(dirname -- "$src")
    case "$new" in */*|""|.|..) t "The name is invalid." files.errInvalidName >&2; exit 1 ;; esac
    [ "$dir/$new" = "$src" ] && exit 0
    { [ -e "$dir/$new" ] || [ -L "$dir/$new" ]; } && { t "“%1” already exists in this folder." files.errExistsHere "$new" >&2; exit 1; }
    mv -- "$src" "$dir/$new" && printf '%s\n' "$dir/$new"
    ;;
props)
    for p in "$@"; do
        LC_ALL=C stat -c "S${US}%n${US}%F${US}%s${US}%W${US}%Y${US}%X${US}%A${US}%U${US}%G" -- "$p"
    done
    # Gesamtgröße und Anzahl (Ordner werden gezählt – kann bei großen Ordnern dauern)
    printf 'T%s%s%s%s%s%s\n' "$US" "$(du -scb -- "$@" 2>/dev/null | tail -n1 | cut -f1)" "$US" \
        "$(find "$@" -mindepth 1 -type f 2>/dev/null | wc -l)" "$US" "$(find "$@" -mindepth 1 -type d 2>/dev/null | wc -l)"
    printf 'M%s%s\n' "$US" "$(file -b --mime-type -- "$1" 2>/dev/null)"
    ;;
mime)
    file -b --mime-type -- "$1" 2>/dev/null
    ;;
info)
    p=$1
    t=$(LC_ALL=C stat -c "%F${US}%s${US}%W${US}%Y" -- "$p") || exit 1
    m=""; c=""; d=""
    if [ -d "$p" ]; then c=$(find "$p" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    else m=$(file -b --mime-type -- "$p" 2>/dev/null)
        case "$m" in image/*) d=$(file -b -- "$p" 2>/dev/null | head -n1) ;; esac
    fi
    printf '%s%s%s%s%s%s%s\n' "$t" "$US" "$m" "$US" "$c" "$US" "$d"
    ;;
preview)
    head -c 6000 -- "$1" 2>/dev/null
    ;;
compress)
    dest=$1; name=$2; shift 2
    command -v bsdtar >/dev/null || { t "bsdtar is missing (package libarchive)." files.errNoBsdtar >&2; exit 1; }
    n=$(unique "$dest" "$name")
    # jede Quelle mit ihrem eigenen Ordner (-C), damit im Archiv nur der Name steht
    cnt=$#
    for s in "$@"; do
        f=${s##*/}; case "$f" in -*) f="./$f" ;; esac
        set -- "$@" -C "$(dirname -- "$s")" "$f"
    done
    shift "$cnt"
    bsdtar -a -cf "$dest/$n" "$@" && printf '%s\n' "$dest/$n" || { rm -f -- "$dest/$n"; exit 1; }
    ;;
extract)
    a=$1; how=$2; dir=$(dirname -- "$a"); base=${a##*/}
    command -v bsdtar >/dev/null || { t "bsdtar is missing (package libarchive)." files.errNoBsdtar >&2; exit 1; }
    case "$base" in
        *.tar.gz|*.tar.xz|*.tar.zst|*.tar.bz2) base=${base%.tar.*} ;;
        *.*) base=${base%.*} ;;
    esac
    if [ "$how" = folder ]; then
        out="$dir/$(unique "$dir" "$base")"
        mkdir -- "$out" && bsdtar -xf "$a" -C "$out" && printf '%s\n' "$out" || { rm -rf -- "$out"; exit 1; }
    else
        # nur oberste Einträge, die es vorher nicht gab (für Rückgängig); Vorhandenes wird nicht überschrieben
        new=$(bsdtar -tf "$a" | sed 's|^\./||; s|/.*||' | awk 'NF && !seen[$0]++' | while IFS= read -r e; do [ -e "$dir/$e" ] || printf '%s\n' "$dir/$e"; done)
        bsdtar -xkf "$a" -C "$dir" || exit 1
        [ -n "$new" ] && printf '%s\n' "$new"
    fi
    ;;
search)
    dir=$1; q=$2; hidden=$3
    pat="*$(printf '%s' "$q" | sed 's/[][*?\\]/\\&/g')*"
    fmt="%y${US}%s${US}%T@${US}%p\n"
    if [ "$hidden" = 1 ]; then find "$dir" -mindepth 1 -iname "$pat" -printf "$fmt" 2>/dev/null
    else find "$dir" -mindepth 1 -name '.*' -prune -o -iname "$pat" -printf "$fmt" 2>/dev/null; fi | head -n 2000
    ;;
*)
    echo "unknown command: $cmd" >&2; exit 2 ;;
esac
