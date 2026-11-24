# Migrationen

`etude-setup` führt beim Anmelden jede Datei `NNN-name.sh` aus diesem Ordner **genau einmal** aus,
in der Reihenfolge der Nummer. Der Stand steht in `~/.local/state/etude/migration`.

- Nummern nie wiederverwenden, nur hochzählen: `001-…`, `002-…`
- Jede Migration muss mehrfach laufen dürfen, ohne Schaden anzurichten (z. B. nach einem Abbruch).
- Exit-Code ≠ 0: Die Migration und alle danach werden beim nächsten Anmelden wiederholt.
- Einstellungen ändern über `etude-config` (z. B. `etude-config set taskbar position bottom`).

Beispiel `002-rename-key.sh`:

```sh
#!/bin/sh
v=$(etude-config get taskbar oldKey)
[ "$v" = "null" ] || { etude-config set taskbar newKey "$v"; etude-config reset taskbar oldKey; }
```
