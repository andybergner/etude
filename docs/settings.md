# Einstellungen

Etude speichert Einstellungen nach dem Vorbild von Windows-Registry und GNOME GSettings:
in **Bereichen** (Domains), mit **Schema** und drei **Ebenen**. Die Dateien bleiben lesbares JSON.

## Ebenen (die untere gewinnt)

| Ebene  | Ort                                              | Inhalt                                       |
|--------|--------------------------------------------------|----------------------------------------------|
| Schema | `default/schemas/<domain>.json` (Paket: `/usr/share/etude/default/schemas`, eigenständige Apps: `/usr/share/etude/schemas`) | Typ, Standardwert, Beschreibung |
| Admin  | `/etc/etude/settings/<domain>.json`              | `{ "values": { … }, "locked": ["key"] }`     |
| Nutzer | `~/.config/etude/settings/<domain>.json`         | nur Werte, die vom Standard abweichen        |

- Ein Wert gleich dem Standard wird **nicht** gespeichert – so kommen geänderte Standards per Update an.
- `locked` sperrt Schlüssel: Der Admin-Wert gilt, der Nutzer kann ihn nicht ändern.
- „Auf Standard zurücksetzen“ = Schlüssel aus der Nutzerdatei löschen (oder die ganze Datei).
- Geschrieben wird atomar (temporäre Datei + Umbenennen); laufende Programme sehen Änderungen sofort.

## Bereiche des Systems

`appearance`, `taskbar`, `time`, `power`, `display`, `notifications`, `files` – siehe `default/schemas/`.
Eigenständige Apps nehmen ihre Reverse-DNS-ID, z. B. `com.example.snip`.

## Schema

```json
{
  "dark":      { "type": "bool",  "default": true, "summary": "Dark mode" },
  "nightTemp": { "type": "int",   "default": 4000, "min": 1000, "max": 6500 },
  "position":  { "type": "enum",  "default": "bottom", "choices": ["bottom", "top"] }
}
```

Typen: `bool`, `int`, `real` (mit `min`/`max`), `string`, `color` (`""` oder `#RRGGBB`/`#AARRGGBB`),
`enum` (mit `choices`), `list`, `object`. Beschreibungen auf Englisch.

## In QML (Etude.Ui)

```qml
import Etude.Ui

Config { id: cfg; domain: "files" }

Switch { checked: cfg.values.details; onToggled: cfg.set("details", checked) }
cfg.value("details", false)   // mit Ersatzwert
cfg.reset("details")
cfg.isLocked("details")
```

Eigenständige App mit eigenem Schema:

```qml
Config { domain: "com.example.snip"; schema: Qt.resolvedUrl("schema.json") }
```

`Theme` liest `appearance` selbst – jede App mit `import Etude.Ui` folgt Hell/Dunkel,
Akzentfarbe und Transparenz des Systems.

`EtudeConfig` (Etude.Services) ist nur noch eine Kompatibilitätsschicht mit den alten
flachen Namen (`config.dark`, `config.set("barLayout", …)`). Neuer Code nimmt `Config`.

## Kommandozeile

```sh
etude-config domains
etude-config list appearance
etude-config describe power
etude-config get taskbar position
etude-config set appearance accent "#2563eb"
etude-config set power idleAcLock 10
etude-config reset appearance accent
etude-config migrate        # alte settings.json verteilen (läuft automatisch)
```

## Neuer Schlüssel / Migration

1. Schlüssel mit Typ, Standard und `summary` ins Schema eintragen.
2. Lesen mit `cfg.values.key`, schreiben mit `cfg.set("key", …)`.
3. Wird ein Schlüssel umbenannt oder verschoben, gehört ein Migrationsschritt nach `etude-config migrate`
   (später: `etude-setup`).
