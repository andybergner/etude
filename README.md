# Etude

Eigenes Arch-Linux-Desktop-System nach dem Vorbild von Omarchy – schlank und komplett selbst
geschrieben: **Hyprland** (Lua-Config), **Quickshell** (QML) für Leiste, Startmenü und
Sperrbildschirm, **kitty** als Terminal und eigene Apps im Design von **shadcn/ui**.

Version 1 – Codename *Etude*.

## Aufbau

Nach dem Vorbild von Omarchy: Code, Vorgaben (`default/`) und Vorlagen für den Nutzer (`config/`)
liegen getrennt. Im Paket landet alles unverändert unter `/usr/share/etude` (= `ETUDE_HOME`).

```
etude/
├── apps/                    Eigene Programme (je App eine App-ID): settings, files, taskmanager
├── shell/                   Desktop-Shell (Quickshell): Leiste, Startmenü, Benachrichtigungen, Sperre …
├── greeter/                 Anmeldebildschirm (Quickshell)
├── qml/Etude/               QML-Module – Importpfad ist qml/
│   ├── Ui/                  import Etude.Ui        (SDK: Theme, Komponenten, i18n, Config)
│   ├── Services/            import Etude.Services  (Netzwerk, Audio, Akku, EtudeConfig …)
│   ├── Lock/                import Etude.Lock      (Sperr- und Anmeldebildschirm)
│   └── Menus/               import Etude.Menus     (Netzwerk-, Ton-, Bluetooth-, Akku-Menü)
├── default/                 Etude-Vorgaben – werden nicht vom Nutzer bearbeitet
│   ├── hypr/                Hyprland-Defaults (env, bindings, rules, looknfeel …)
│   ├── kitty/               kitty-Defaults
│   ├── greeter/             greetd.toml, Hyprland für den Anmeldebildschirm
│   ├── i18n/<sprache>/      Übersetzungen, eine Datei pro Bereich (settings.json, bar.json …)
│   ├── schemas/             Einstellungs-Schemas (Typ, Standardwert)
│   ├── limine/ snapper/     Bootloader und Schnappschüsse (für install/)
│   ├── systemd/ tmpfiles.d/ polkit/ wayland-sessions/   Systemdateien
│   ├── wallpapers/          Mitgelieferte Hintergründe
│   └── shim/                xdg-open → etude-open (vorne im PATH der Sitzung)
├── config/                  Vorlagen für ~/.config – gehören danach dem Nutzer
│   ├── hypr/hyprland.lua    lädt default/hypr, darunter eigene Änderungen
│   └── kitty/kitty.conf     lädt default/kitty, darunter eigene Änderungen
├── applications/            Startmenü-Einträge (*.desktop.in) und icons/
├── migrations/              Einmalige Anpassungen pro Nutzer (etude-setup)
├── bin/                     etude-settings, etude-setup, etude-config, etude-dev-link …
├── install/                 Installations-Bausteine: Paketlisten, hardware/, config/, user/
├── iso/                     Etude-ISO (archiso) mit dem Installer etude-install
├── packaging/               PKGBUILDs (etude, etude-ui), AUR-Pakete fürs Repo
├── scripts/                 Entwickler-Skripte (Release, i18n prüfen, Wallpaper erzeugen …)
├── branding/                Logo
└── docs/                    Dokumentation, examples/
```

## Wo Etude liegt: `ETUDE_HOME`

Alle Etude-Programme finden ihre Dateien über die Variable `ETUDE_HOME`:

| | `ETUDE_HOME` | Programme | QML-Module |
|---|---|---|---|
| Paket | `/usr/share/etude` | `/usr/bin` | `/usr/lib/qt6/qml` |
| Entwicklung | das Repo | `$ETUDE_HOME/bin` (im PATH) | `$ETUDE_HOME/qml` (QML_IMPORT_PATH) |

Den Entwicklungsmodus schaltet `bin/etude-dev-link` ein: Es schreibt den Repo-Pfad nach
`~/.config/etude/dev-home`. `default/hypr/env.lua` liest die Datei und setzt `ETUDE_HOME`,
`PATH` und `QML_IMPORT_PATH` für alles, was Hyprland startet. Ohne die Datei gilt das Paket.
Etude-Programme werden überall über ihren Namen gestartet (`etude-settings`, `etude-files` …).

Nutzerdaten liegen nie unter `ETUDE_HOME` (siehe `Etude.Services/Paths`):
Einstellungen `~/.config/etude`, eigene Daten `~/.local/share/etude`, Verlauf `~/.local/state/etude`,
Zwischenspeicher `~/.cache/etude`.

## Entwicklung

```bash
git clone … ~/dev/etude
~/dev/etude/bin/etude-dev-link      # Symlinks anlegen (einmalig)
sudo install -Dm644 ~/dev/etude/default/polkit/rules.d/50-etude.rules /etc/polkit-1/rules.d/
# neu anmelden – danach läuft die Shell automatisch

~/dev/etude/bin/etude-dev-shell     # Shell neu starten (auch per SSH)
etude-settings [seite]              # Einstellungen, z. B. "sound", "wifi", "cursor"
```

Abhängigkeiten: siehe `depends` in `packaging/etude/PKGBUILD` und `packaging/etude-ui/PKGBUILD`.

## Installieren als Paket

Siehe [docs/packaging.md](docs/packaging.md): Pacman-Repo eintragen, `sudo pacman -Sy etude`,
mit der Sitzung „Etude“ anmelden. Releases: `scripts/release.sh ui|etude <version>`.

## Einstellungen speichern

| Datei | Inhalt | geschrieben von |
|---|---|---|
| `~/.config/etude/settings/<bereich>.json` | Theme, Akzent, Transparenz, Hintergrund, Taskleiste, Uhr, Energie … (siehe [docs/settings.md](docs/settings.md)) | `Config` / `etude-config` |
| `~/.config/hypr/etude-settings.lua` | Fenster-Layout, Bildschirme, Tastatur, Maus, Touchpad, Proxy | Einstellungen (`HyprSettings`) |
| `~/.config/kitty/etude-transparency.conf` | Transparenz für kitty | Shell |

Shell und Apps beobachten `settings.json` – Änderungen wirken sofort überall.

## Konventionen

- **App-IDs** in Reverse-DNS: `com.etude.settings`, später `com.etude.files` …
  Gleicher Name für `.desktop`-Datei, Icon, PID-Datei und (mit eigenem Qt-Binary) Wayland-`app_id`.
- **Hover** immer mit `HoverLayer { shown: … }`, nie über eine animierte Hintergrundfarbe.
- **Farb-Animationen** mit `Behavior on color { enabled: Theme.animate; … }`, damit der
  Theme-Wechsel nicht flackert.
- **Klickbare Flächen** bekommen `cursorShape: Qt.PointingHandCursor`.

## Lizenz

MIT – siehe [LICENSE](LICENSE).
