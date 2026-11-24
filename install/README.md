# install/ – Bausteine der Etude-Installation

Nach dem Vorbild von [Omarchy](https://github.com/basecamp/omarchy) (`install/`). Der Installer
der ISO (`iso/etude-install`) stellt die Fragen, partitioniert und ruft `pacstrap` auf – alles,
was danach im neuen System passiert, steht hier. Jeder Ordner hat ein `all.sh`, das seine
Skripte der Reihe nach aufruft.

| Ordner / Datei | Läuft als | Inhalt |
|---|---|---|
| `etude-base.packages` | – | Pakete für `pacstrap` |
| `etude-boot.packages` | – | Bootmenü-Werkzeuge aus dem `[etude]`-Repo (optional) |
| `etude-hardware.packages` | – | alle Pakete, die `hardware/` nehmen kann – die ISO legt sie ins Offline-Repo |
| `helpers/common.sh` | – | Protokoll, Hardware-Erkennung (`gpu_intel`, `gpu_hybrid_nvidia`, `cpu_intel` …), Paket-Warteschlange, `limine_dropin` |
| `hardware/` | root | Microcode, Grafik, Laptop-Fixes. Fehler = Warnung |
| `config/` | root | Sprache, Tastatur, Gerätename, sudo, zram, Dienste, Spiegelliste, snapper, Limine. Fehler = Abbruch |
| `user/` | Benutzer | Standardordner |
| `../default/limine`, `../default/snapper` | – | Vorlagen (Limine mit `@@CMDLINE@@`, snapper) – liegen wie bei Omarchy im Ordner `default/` des Repos |

Reihenfolge im Installer: `hardware/` → `config/` (Limine zuletzt, damit es die Bootparameter
aus `hardware/` kennt) → `user/`.

## Werte aus dem Installer

Der Installer legt `env` neben die Skripte: `ETUDE_LOCALE`, `ETUDE_KEYMAP`, `ETUDE_XKB`,
`ETUDE_XKB_VARIANT`, `ETUDE_TZ`, `ETUDE_HOSTNAME`, `ETUDE_ROOT_UUID`, `ETUDE_DISK`,
`ETUDE_PACMAN_CONF` (Offline-Installation: pacman.conf für das Repo der ISO).
Fehlt ein Wert, lässt das Skript die Einstellung unverändert – so kann man die Skripte auch
auf einem fertigen System laufen lassen:

```bash
sudo bash /usr/share/etude/install/hardware/all.sh     # nach einem Hardwarewechsel
sudo bash /usr/share/etude/install/config/limine.sh    # Bootloader neu aufsetzen
```

## Neuen Hardware-Fix hinzufügen

1. `hardware/<name>.sh` anlegen: `common.sh` einbinden, zuerst prüfen, ob der Computer passt
   (sonst `exit 0`), Pakete mit `pkg_add`, Kernel-Parameter mit `limine_dropin`.
2. In `hardware/all.sh` in die Liste eintragen.
3. Jedes Paket aus `pkg_add` in `etude-hardware.packages` eintragen – sonst fehlt es bei der
   Offline-Installation.
