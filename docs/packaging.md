# Pakete und Updates

Etude besteht aus zwei Paketen mit eigener Version – wie Windows und die Windows App SDK:

| Paket      | Inhalt                                                        | installiert nach |
|------------|---------------------------------------------------------------|------------------|
| `etude-ui` | SDK: `Etude.Ui` (Theme, Komponenten, i18n, `Config`), `etude-config`, `etude-i18n` | `/usr/lib/qt6/qml/Etude/Ui`, `/usr/bin` |
| `etude`    | System: Shell, Einstellungen, Explorer, Task-Manager, `Etude.Services`, Hyprland-Konfiguration, Sitzung | `/usr/share/etude`, `/usr/lib/qt6/qml/Etude/Services`, `/usr/bin` |

`etude` hängt von `etude-ui>=X` ab. Eigenständige Apps (eigenes Repo) hängen nur von `etude-ui` ab
und folgen trotzdem Theme, Akzentfarbe und Sprache des Systems.

PKGBUILDs: `packaging/etude-ui/PKGBUILD`, `packaging/etude/PKGBUILD`.

## Lokal bauen und testen

```sh
cd ~/dev/etude/packaging/etude-ui && ETUDE_SRC=~/dev/etude makepkg -sif
cd ~/dev/etude/packaging/etude    && ETUDE_SRC=~/dev/etude makepkg -sif
```

`ETUDE_SRC` nimmt den aktuellen Stand deines Checkouts (auch ohne Commit). Ohne `ETUDE_SRC` holt
`makepkg` den Code über den Git-Tag des Releases.

Zum Testen des **installierten** Etude den Entwicklungsmodus ausschalten und neu anmelden:

```sh
mv ~/.config/etude/dev-home ~/.config/etude/dev-home.off   # zurück: wieder umbenennen
```

## Vor jedem Release: Testbuild

```sh
scripts/test-install.sh 0.1.0-alpha.1   # baut etude-ui und etude aus deinem Arbeitsstand und installiert sie
sudo reboot                        # falls Anmeldebildschirm, systemd oder polkit betroffen sind
```

Der Testbuild heißt `0.1.0alpha1-0.<datum><uhrzeit>`. Das echte Release `0.1.0alpha1-1` ist für pacman neuer:
Nach dem Release bietet „Etude Update“ es an – so ist auch der Update-Weg getestet.
Zurück zur Repo-Version ohne Release: `sudo pacman -Syuu`.

Ablauf:

1. **Entwicklungsmodus** – Oberfläche ändern und sofort sehen (`~/.config/etude/dev-home`).
   Der Anmeldebildschirm lässt sich als Vorschau öffnen: `timeout 20 qs -p greeter` (ohne Anmelden).
2. **Testbuild** – `scripts/test-install.sh <version>`, neu starten, alles durchklicken.
3. **Release** – `scripts/release.sh etude <version>`, danach in „Etude Update“ installieren.

## Release

```sh
scripts/release.sh ui 0.1.0-alpha.1       # etude-ui (immer zuerst – etude braucht es)
scripts/release.sh etude 0.1.0-alpha.1    # etude
```

Das Skript setzt `pkgver`, committet, setzt den Tag (`ui-v0.1.0-alpha.1` / `etude-v0.1.0-alpha.1`)
und pusht.
GitHub Actions (`.github/workflows/release.yml`) baut dann das Paket in einem Arch-Container und
legt es ins Pacman-Repo – das GitHub-Release mit dem Namen `repo`.

### Versionen

| Schreibweise (Tag, Skript) | pkgver (pacman) | wofür |
|---|---|---|
| `0.1.0-alpha.1` | `0.1.0alpha1` | früher Stand zum Ausprobieren, es fehlt noch einiges |
| `0.1.0-beta.1` | `0.1.0beta1` | alles da, wird getestet |
| `0.1.0-rc.1` | `0.1.0rc1` | Release-Kandidat: wird so veröffentlicht, wenn kein Fehler auftaucht |
| `0.1.0` | `0.1.0` | fertige Version |

pacman erlaubt keinen Bindestrich in `pkgver`, deshalb `0.1.0alpha1`. Die Reihenfolge stimmt
trotzdem: `0.1.0alpha1 < 0.1.0alpha2 < 0.1.0beta1 < 0.1.0rc1 < 0.1.0 < 0.1.1` – „Etude Update“
bietet also jede neuere Vorabversion und am Ende die fertige Version an.

`0.x` bis zur ersten stabilen Version. Danach bei `etude-ui`: neue Komponenten = kleine
Version (1.3 → 1.4), Entfernen/Umbenennen = neue Hauptversion (2.0).

## Installieren (für Nutzer)

`/etc/pacman.conf`:

```ini
[etude]
SigLevel = Optional TrustAll
Server = https://github.com/andybergner/etude/releases/download/repo
```

```sh
sudo pacman -Sy etude
```

Danach mit der Sitzung **Etude** anmelden (Login-Manager) oder auf der Konsole `etude-session`.
Updates kommen mit `pacman -Syu`.

> Noch unsigniert. Vor der Veröffentlichung für andere: Pakete mit GPG signieren, `SigLevel` auf `Required`.

## Erstes Anmelden und Updates: `etude-setup`

`etude-session` ruft bei jedem Anmelden `etude-setup` auf, danach startet Hyprland. `etude-setup`:

1. verlinkt `~/.config/hypr/etude` → `/usr/share/etude/default/hypr` und legt `hyprland.lua` und
   `kitty.conf` an, falls es sie nicht gibt (eigene Dateien werden nie überschrieben),
2. legt die Einstellungsbereiche an und verteilt eine alte `settings.json` (`etude-config migrate`),
3. führt neue Migrationen aus `migrations/` aus (siehe dort).

## Wo was liegt

| | Paket | Entwicklung |
|---|---|---|
| `ETUDE_HOME` | `/usr/share/etude` | das Repo (`~/.config/etude/dev-home`) |
| Programme | `/usr/bin` | `$ETUDE_HOME/bin` (im PATH) |
| QML-Module | `/usr/lib/qt6/qml` | `$ETUDE_HOME/qml` (QML_IMPORT_PATH) |
| Schemas | `/usr/share/etude/default/schemas` (eigenständige Apps: `/usr/share/etude/schemas`) | `$ETUDE_HOME/default/schemas` |
| Übersetzungen | `/usr/share/etude/default/i18n` | `$ETUDE_HOME/default/i18n` |
| Einstellungen | `~/.config/etude/settings` | gleich |
| Eigene Daten / Verlauf | `~/.local/share/etude`, `~/.local/state/etude` | gleich |
