#!/bin/sh
# Messwerte für den Task-Manager, ein Durchlauf je Aufruf (alle 1,5 s).
#   sample.sh        laufende Werte: CPU, Speicher, Datenträger, Netzwerk, Prozesse
#   sample.sh info   feste Angaben: CPU-Modell, Kerne, Laufwerke, Adapter, Benutzer
# Zeilen beginnen mit einer Kennung; Felder durch Leerzeichen bzw. \037 getrennt.

if [ "$1" = info ]; then
    echo "MODEL $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
    echo "CORES $(grep -c ^processor /proc/cpuinfo) $(lscpu -p=core 2>/dev/null | grep -v '^#' | sort -u | wc -l)"
    echo "SOCKETS $(lscpu -p=socket 2>/dev/null | grep -v '^#' | sort -u | wc -l)"
    echo "MAXMHZ $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0)"
    echo "PAGESIZE $(getconf PAGESIZE)"
    echo "HZ $(getconf CLK_TCK)"
    for d in /sys/block/*; do
        n=${d##*/}
        case "$n" in loop*|ram*|zram*|dm-*|sr*|md*) continue ;; esac
        size=$(( $(cat "$d/size" 2>/dev/null || echo 0) * 512 ))
        [ "$size" -gt 0 ] || continue
        model=$(cat "$d/device/model" 2>/dev/null | sed 's/ *$//')
        rot=$(cat "$d/queue/rotational" 2>/dev/null || echo 0)
        printf 'DISK %s %s %s %s\n' "$n" "$size" "$rot" "${model:-Datenträger}"
    done
    for d in /sys/class/net/*; do
        n=${d##*/}
        [ "$n" = lo ] && continue
        [ -e "$d/device" ] || continue
        kind=ethernet; [ -e "$d/wireless" ] && kind=wifi
        printf 'NIC %s %s %s\n' "$n" "$kind" "$(cat "$d/speed" 2>/dev/null || echo 0)"
    done
    getent passwd | awk -F: '{ print "USER", $3, $1 }'
    exit 0
fi

echo "#T $(cut -d' ' -f1 /proc/uptime)"
grep '^cpu' /proc/stat
grep -E '^(MemTotal|MemAvailable|MemFree|Buffers|Cached|SwapTotal|SwapFree|Committed_AS|CommitLimit|Shmem|SReclaimable):' /proc/meminfo | sed 's/^/M /'
awk '{ print "D", $3, $6, $10, $13 }' /proc/diskstats
sed -n '3,$p' /proc/net/dev | tr ':' ' ' | awk '{ print "N", $1, $2, $10 }'
echo "F $(grep 'cpu MHz' /proc/cpuinfo | awk '{ s += $4; n++ } END { if (n) printf "%d", s / n; else print 0 }')"
for g in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$g" ] && echo "G $(cat "$g")"; break; done
# Prozesse: P pid state ppid ticks rss threads comm   (comm kann Leerzeichen enthalten → steht am Ende)
awk '{
    lp = index($0, "("); rp = 0
    for (k = length($0); k > 0; k--) if (substr($0, k, 1) == ")") { rp = k; break }
    if (!lp || !rp) next
    pid = substr($0, 1, lp - 2); comm = substr($0, lp + 1, rp - lp - 1)
    n = split(substr($0, rp + 2), f, " ")
    print "P", pid, f[1], f[2], f[12] + f[13], f[22], f[18], comm
}' /proc/[0-9]*/stat 2>/dev/null
stat -c 'U %n %u' /proc/[0-9]* 2>/dev/null
awk '/^read_bytes/ { r = $2 } /^write_bytes/ { print "I", FILENAME, r, $2 }' /proc/[0-9]*/io 2>/dev/null
exit 0
