# Anmeldebildschirm (greetd)

Etude meldet über [greetd](https://git.sr.ht/~kennylevinsen/greetd) an. Die Oberfläche ist dieselbe
wie beim Sperrbildschirm (`shell/modules/lock/LockSurface.qml`), nur kommt die Prüfung von greetd
statt von PAM, und unten links steht die Nutzerauswahl.

```
greetd (root)
 └─ etude-greeter  (Nutzer „greeter“)
     └─ Hyprland --config default/greeter/hyprland.lua  kleines Hyprland nur für die Anmeldung
         └─ qs -p greeter                            Anmeldebildschirm
              Kennwort → greetd prüft (PAM) → greetd startet etude-session als dieser Nutzer
                                              → etude-setup → Hyprland → Etude
```

## Einrichtung

Nichts zu tun: Der Anmeldebildschirm gehört fest zum System.

- `greetd` ist eine Abhängigkeit von `etude`. Das Paket bringt `/usr/lib/systemd/system/greetd.service.d/etude.conf`
  mit, das greetd auf `/usr/share/etude/default/greeter/greetd.toml` umstellt – `/etc/greetd/config.toml` bleibt unberührt.
- Installation und jedes Update aktivieren `greetd.service` (`etude.install`).
- `/usr/lib/tmpfiles.d/etude.conf` legt `/etc/etude/greeter` und `/var/lib/etude-greeter` an.

**Notausgang**, falls nichts mehr geht: <kbd>Strg</kbd>+<kbd>Alt</kbd>+<kbd>F2</kbd> → anmelden →
`sudo systemctl disable greetd` → neu starten.

## Hyprland für den Greeter

`etude-greeter` startet Hyprland über `start-hyprland` (ohne bricht Hyprland 0.57 beim Anzeigen seiner
Warnung ab) und gibt ihm bei jedem Start einen frischen Arbeitsordner (`/tmp/etude-greeter.XXXXXX` für
Cache, Zustand und Daten). Sonst hielte `start-hyprland` das Beenden durch greetd beim Login für einen
Absturz und startete beim nächsten Mal im Safe Mode – ohne Etude-Konfiguration.

## Aussehen

Der Anmeldebildschirm läuft als Nutzer `greeter` und kann `~/.config/etude` nicht lesen. Er nimmt:

| | Quelle |
|---|---|
| Sprache | `/etc/locale.conf` |
| Tastatur | `localectl` (X11-Layout) bzw. `/etc/vconsole.conf` |
| Hell/Dunkel, Akzent, Hintergrund | `/etc/etude/greeter/appearance.json` und `/etc/etude/greeter/wallpaper` |
| Bildschirme (Auflösung, Skalierung, Anordnung) | `/etc/etude/greeter/monitors.lua` (+ `monitors.json`), fehlt sie: automatisch |
| Profilbilder | `/var/lib/AccountsService/icons/<nutzer>` (Einstellungen › Konten setzt das mit) |
| zuletzt angemeldet | `/var/lib/etude-greeter/last-user` |
| Log (Tastatur, Arbeitsordner) | `/var/lib/etude-greeter/greeter.log` |
| Ausgabe des Greeter-Hyprland | `/tmp/etude-greeter.XXXXXX/hyprland.log` |
| Ausgabe der Sitzung (etude-setup, Hyprland) | `~/.local/state/etude/session.log` (vorige: `.old`) |

Das hält die Shell automatisch aktuell (`shell/modules/lock/GreeterSync.qml`): Ändert sich Hintergrund,
Hell/Dunkel oder Akzentfarbe, ruft sie nach 2 s `pkexec etude-greeter appearance <bild|-> <json>` auf.
Ändern sich die Bildschirme (Einstellungen › Bildschirm schreibt `~/.config/hypr/etude-settings.lua` mit
der Zeile `-- etude-monitors: {…}`), ruft sie `pkexec etude-greeter display <json>` auf; `etude-greeter`
prüft jeden Wert (Ausgangsname, Auflösung, Skalierung 0,25–4 …) und erzeugt daraus erst dann Lua.
Die polkit-Regel (`default/polkit/rules.d/50-etude.rules`) erlaubt genau diese Befehle für aktive lokale
Nutzer in `wheel` ohne Passwort. `etude-greeter` liest das Bild dabei als der aufrufende Nutzer
(`PKEXEC_UID`) und nimmt nur echte Bilder – fremde Dateien lassen sich so nicht nach `/etc` kopieren.
Nutzer außerhalb von `wheel` und der Entwicklungsmodus synchronisieren nicht (sonst käme eine Passwortabfrage).

## Entwickeln

Die Oberfläche lässt sich ohne greetd ansehen: `timeout 20 qs -p greeter` (Anmelden geht dann nicht).

Sperr- und Anmeldebildschirm teilen sich `LockSurface` über das QML-Modul **`Etude.Lock`**
(`qml/Etude/Lock`, im Paket `/usr/lib/qt6/qml/Etude/Lock`). Ein Zugriff von `greeter/` auf `../shell/…`
geht nicht: Quickshell lädt Dateien nur aus dem eigenen Konfigurationsordner, Module dagegen über den Import-Pfad.
Wichtig in QML-Dateien für Quickshell: keine `{` im Kopf vor dem letzten `import`, auch nicht in Kommentaren
(sonst liest Quickshell die imports nicht) – `scripts/qml-headercheck.py` prüft das.
Änderungen am Sperrbildschirm wirken automatisch auch hier.
