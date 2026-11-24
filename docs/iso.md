# Etude-ISO

Installationsmedium für Etude: Live-System (archiso, Profil `releng`) mit dem Installer
`etude-install`. Er installiert Etude auf die **ganze Festplatte** – wie bei Omarchy **ohne
Internet**: Alle Pakete liegen als Offline-Repo auf dem USB-Stick.

## Der Installer

Vollbild mit Etude-Logo, ein Schritt pro Seite:

1. Sprache → 2. Tastatur → 3. Zeitzone → 4. Netzwerk (optional, wird übersprungen, wenn schon
   verbunden) → 5. Konto (Name, Benutzername, Kennwort, Gerätename) → 6. Festplatte
2. **Übersicht**: jeder Punkt lässt sich auswählen und ändern, dann „Installieren“
3. Letzte Warnung (Festplatte wird gelöscht), danach läuft alles von selbst mit Fortschrittsbalken

Bedienung: Pfeiltasten + Enter, **Esc = einen Schritt zurück**. Bei einem Fehler: Protokoll
ansehen, Installer neu starten oder zur Konsole.

## Was installiert wird

| | |
|---|---|
| Partitionen | GPT: 2 GiB EFI (FAT32, als `/boot`) + btrfs |
| btrfs | Subvolumes `@` `/`, `@home`, `@log` `/var/log`, `@pkg` Paket-Cache, `@snapshots`; `compress=zstd:1` |
| Bootloader | Limine (UEFI), stilles Booten, Einträge von `limine-update` (wie Omarchy), „Notfall“-Eintrag |
| Schnappschüsse | snapper + snap-pac: vor und nach jedem Update, 5 behalten, **im Bootmenü startbar** (`limine-snapper-sync`) |
| System | `base`, `linux`, `linux-firmware`, Microcode (Intel/AMD automatisch), Grafiktreiber (Intel/AMD automatisch), `sof-firmware` (Laptop-Ton), PipeWire, NetworkManager, zram, Chromium |
| Etude | `etude` aus dem `[etude]`-Repo → Anmeldebildschirm, Bluetooth, Energiemodus aktiv |
| Konto | Benutzer in `wheel` (sudo), root gesperrt |
| Sprache | Deutsch oder Englisch, Tastatur und Zeitzone nach Wahl |

Nicht dabei (noch): Verschlüsselung, Dual-Boot, BIOS/Legacy, NVIDIA-Treiber.

## Aufbau: `iso/` und `install/`

Wie bei Omarchy ist der Installer nur die dünne Schicht oben drauf:

| | |
|---|---|
| `iso/etude-install` | Oberfläche (gum), Partitionen, `pacstrap`, Benutzer |
| `install/etude-base.packages` | Pakete für `pacstrap` |
| `install/etude-hardware.packages` | Pakete, die `hardware/` je nach Computer nimmt – kommen mit ins Offline-Repo |
| `install/etude-boot.packages` | `limine-mkinitcpio-hook`, `limine-snapper-sync` (optional, aus dem `[etude]`-Repo) |
| `install/hardware/` | Microcode, Grafik, Laptop-Fixes – erkennt die Hardware über `/sys/bus/pci` |
| `install/config/` | Sprache, Tastatur, sudo, zram, Spiegelliste, snapper, **Limine** (zuletzt) |
| `install/user/` | pro Benutzer (Ordner) |
| `default/limine`, `default/snapper` | Vorlagen: `limine/default.conf` (mit `@@CMDLINE@@`), `limine/etude.conf`, `limine/limine.conf`, `snapper/root` |

Details: `install/README.md`. Die Bausteine liegen auch im Paket `etude` unter
`/usr/share/etude/install` und lassen sich auf einem installierten System erneut ausführen.

### Bootloader wie Omarchy

- `/etc/default/limine` entsteht aus `default/limine/default.conf`: `@@CMDLINE@@` wird
  durch `root=UUID=… rootflags=subvol=@ rw` ersetzt.
- Zusätze kommen als Dateien nach `/etc/limine-entry-tool.d/` – Etude-Vorgaben (`00-etude.conf`:
  `quiet`, Name „Etude“, Schnappschüsse), Hardware-Fixes (z. B. `50-nvidia-hybrid.conf`).
- `limine-update` schreibt daraus die Einträge in `/boot/limine.conf`, bei jedem Kernel-Update neu.
  Eigene Kernel-Parameter: Datei in `/etc/limine-entry-tool.d/` anlegen, dann `sudo limine-update`.
- `limine-snapper-sync` trägt jeden snapper-Schnappschuss ins Bootmenü ein → nach einem kaputten
  Update im Bootmenü „Snapshots“ wählen. Dauerhaft zurück: `sudo limine-snapper-restore`.
- Die beiden Pakete stammen aus dem AUR und werden von der Action `aur` ins `[etude]`-Repo gebaut
  (`packaging/aur.packages`). Fehlen sie, installiert Etude trotzdem – mit festen Einträgen.

### Offline-Repo wie Omarchy

- `iso/build.sh` lädt beim Bauen alle Pakete aus `install/etude-base.packages`,
  `etude-hardware.packages` und `etude-boot.packages` **samt Abhängigkeiten** und legt sie als
  pacman-Repo `offline` nach `/var/cache/etude/offline` ins Live-System.
- Der Installer nimmt dann `/etc/etude/pacman-offline.conf`: `pacstrap -c -C …` installiert direkt
  aus diesem Repo. Für Hardware-Pakete wird es ins neue System eingehängt und danach entfernt.
- Das neue System bekommt die normale `pacman.conf` (mit `[etude]`). Ist die Spiegelliste leer
  (offline installiert), trägt `install/config/pacman.sh` den weltweiten Arch-Spiegel ein.
- Die Pakete haben den Stand vom Bau der ISO – das erste `sudo pacman -Syu` (bzw. Etude Update)
  bringt alles auf den neuesten Stand.
- Ohne Offline-Repo bauen (kleiner, Installation braucht Internet): `OFFLINE=0 sudo iso/build.sh`.
  Auf einer ISO mit Repo trotzdem aus dem Internet installieren: `ETUDE_ONLINE=1 etude-install`.

## Bauen

**Einmalig vorher:** GitHub → Actions → **aur** → *Run workflow* – baut die Bootmenü-Pakete ins Repo.

Auf einem Arch-System (z. B. der Entwicklungs-VM):

```bash
sudo pacman -S --needed archiso
sudo iso/build.sh                      # → iso/out/etude-YYYY.MM.DD-x86_64.iso
```

Mit Version: `sudo VERSION=0.1.0-alpha.1 iso/build.sh` → `etude-0.1.0-alpha.1-x86_64.iso`.

Oder auf GitHub: `git tag -a iso-v0.1.0-alpha.1 -m "Etude ISO 0.1.0-alpha.1" && git push origin iso-v0.1.0-alpha.1`
– die Action `iso` baut und legt die ISO als Release `iso-v0.1.0-alpha.1` ab (bei `-alpha`,
`-beta`, `-rc` als „Pre-release“; der Installer zeigt dann einen Hinweis). Mit Offline-Repo ist die
ISO etwa 2–3 GB groß; GitHub erlaubt pro Datei höchstens 2 GiB, deshalb wird sie dann in Teile
zerlegt. Zusammensetzen: `cat etude-*.iso.part-* > etude.iso && sha256sum -c SHA256SUMS`.

## Testen in der VM

virt-manager: neue VM, ISO auswählen, **vor dem Start „Konfiguration anpassen“ → Übersicht →
Firmware: UEFI x86_64 (OVMF)** – ohne UEFI startet der Installer nicht. Mindestens 20 GB Platte.

## USB-Stick

```bash
lsblk                                  # Stick finden, z. B. /dev/sdb
sudo dd if=iso/out/etude-*.iso of=/dev/sdb bs=4M status=progress oflag=sync
```

## HP ProBook 450 G6

- BIOS (F10): **Secure Boot aus**, UEFI-Modus (kein Legacy)
- Bootmenü: **F9** beim Einschalten → USB-Stick
- Grafik: Intel UHD 620 (läuft mit `mesa`). Ist zusätzlich eine GeForce MX130 verbaut, schaltet der
  Installer `nouveau` ab (stürzt dort beim Start ab) – das Bild macht die Intel-Grafik.
- Ton (internes Mikrofon) braucht `sof-firmware` – ist dabei.

## Im Live-System

- Der Installer startet auf tty1 automatisch; abbrechen und neu starten mit `etude-install`.
- Netzwerk von Hand: `nmtui`. Protokoll: `/tmp/etude-install.log`.
- Testlauf ohne Festplatte: `ETUDE_DRY_RUN=1 etude-install`.
- Im installierten System liegt das Protokoll unter `/var/log/etude/install.log`.
