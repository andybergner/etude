# Tastaturbedienung (Etude.Ui)

Wie der Browser bei HTML (button, select, input, textarea …): alles, was **fokussierbar** ist,
ist automatisch per Tastatur bedienbar – Bedienelemente aus `Etude.Ui`, aus `QtQuick.Controls`
und eigene Elemente. Apps nutzen dafür `AppWindow` statt `FloatingWindow`:

```qml
AppWindow { title: "Meine App"; MeinInhalt { anchors.fill: parent; focus: true } }
```

(In anderen Fenstern: `FocusRoot { anchors.fill: parent; … }` außen herum legen.)

| Taste | Wirkung |
|---|---|
| Tab / Shift+Tab | nächstes / voriges Bedienelement |
| Pfeiltasten | zum nächsten Bedienelement in Pfeilrichtung (räumlich, wie XYFocus bei Windows) |
| Enter / Leertaste | auslösen (Button, Zeile, Schalter …), Auswahlliste öffnen |
| Alt+Runter | Auswahlliste (Select) öffnen |
| Links/Rechts auf Slider | Wert ändern (Pos1/Ende: Rand) |

## Wie die Pfeil-Navigation funktioniert

`qml/Etude/Ui/FocusNav.js` sucht unter allen per Tab erreichbaren Elementen das nächste in
Pfeilrichtung – zuerst in derselben Spalte bzw. Zeile, sonst das nächstgelegene.
Weggeklappte Inhalte (z. B. ein zugeklappter Expander) werden übersprungen, Elemente in
Flickables werden beim Ansteuern ins Bild gescrollt.

`FocusRoot` (in `AppWindow` eingebaut) fängt alle Tasten ab, die kein Element selbst behandelt:

- Pfeiltasten → nächstes fokussierbares Element in Pfeilrichtung
- Enter / Leertaste → löst Elemente mit einem `clicked()`-Signal aus
- fokussierte Elemente werden ins Bild gescrollt (auch per Tab)
- Elemente ohne eigenen Fokus-Ring bekommen einen (Etude.Ui-Elemente markieren sich mit `ownFocusRing: true`)

Elemente, die Pfeile selbst brauchen (Textfelder, Listen, Slider), behandeln sie zuerst; was sie
nicht brauchen (z. B. eine Liste am Rand), geht weiter an die Navigation.

### Eigene Elemente

Wie `<div tabindex="0">` bei HTML – fokussierbar machen, mehr nicht:

```qml
Item {
    id: own
    activeFocusOnTab: true          // = tabindex="0": per Tab und Pfeilen erreichbar
    signal clicked()                // Enter/Leertaste lösen es automatisch aus
    MouseArea { anchors.fill: parent; onClicked: own.clicked() }
}
```

Ein Element mit nur einer MouseArea (ohne `activeFocusOnTab`) ist – wie ein `<div onclick>` bei
HTML – nicht per Tastatur erreichbar.

### Listen (ListView/GridView)

Eine Liste ist eine Station (wie bei Windows/HTML-Listbox): `activeFocusOnTab: true` auf der View,
Pfeile wandern darin; am Rand nicht annehmen (`e.accepted = false`), dann geht es zum Nachbarn.
Beispiel: `apps/files/pages/FolderView.qml` (`arrowKey`).

### Wie bei Windows: Tab zwischen Gruppen, Pfeile innerhalb

- Jedes Bedienelement (Button, Schalter, Eingabefeld …) ist eine Tab-Station.
- Listen und Raster (Dateien, Prozesse, App-Raster im Startmenü) sind **eine** Station, die Pfeile wandern darin.
- Navigationsleisten (`SidebarMenuButton` in einem Bereich mit `arrowScope`) sind ebenfalls eine
  Station („Roving Tabindex“): Tab landet auf dem aktiven Eintrag, Pfeile wandern, Enter öffnet,
  Tab verlässt die Leiste. Eigene Elemente machen das mit `readonly property bool navigable: true`
  und `activeFocusOnTab: active || activeFocus || FocusNav.rovingFirst(root)`.
- Popups (Startmenü, Schnelleinstellungen, Kalender, Benachrichtigungen, UAC) haben einen
  `FocusRoot`; Esc schließt.

Startmenü: Suche → App-Raster → Benutzer → Ein/Aus. Tippen springt in die Suche, Enter auf
Ein/Aus öffnet das Menü (erster Eintrag markiert), Esc schließt es wieder auf den Button.

### Bereiche (optional)

Ein Container kann einen Bereich bilden, z. B. eine Seitenleiste:

```qml
Rectangle {
    property string arrowScope: "sidebar"   // Hoch/Runter bleibt im Bereich
    property string arrowEnter: "active"    // betreten → Eintrag mit active: true ("first", "nearest")
    property string arrowRight: "content"   // Rechts am Rand → Bereich "content" (auch arrowLeft/Up/Down)
}
```

Ohne Bereiche funktioniert alles rein räumlich.
