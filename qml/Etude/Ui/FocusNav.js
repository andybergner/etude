.pragma library
// Pfeiltasten-Navigation für alle Etude.Ui-Bedienelemente (wie XYFocus bei Windows/WinUI).
//
// Wie beim Browser für HTML: alles, was fokussierbar ist (per Tab erreichbar – Buttons aus
// Etude.Ui oder QtQuick.Controls, Eingabefelder, eigene Elemente mit activeFocusOnTab: true),
// ist automatisch per Pfeiltasten erreichbar. Gesucht wird räumlich: das nächste Element in
// Pfeilrichtung. Die Fenster-Ebene macht FocusRoot (in AppWindow eingebaut); die Etude.Ui-
// Bedienelemente rufen FocusNav.key(root, event) zusätzlich selbst auf (geht auch ohne FocusRoot).
//
// Optional – Bereiche (ein Container mit diesen Properties):
//   property string arrowScope: "sidebar"   Hoch/Runter bleibt im Bereich (kein Ausbrechen am Rand)
//   property string arrowEnter: "active"    beim Betreten: "active" (Element mit active: true),
//                                           "first" (oberstes) oder "nearest" (Standard)
//   property string arrowRight: "content"   Rechts am Rand → Bereich "content" (auch arrowLeft/Up/Down)

// ---------- Hilfen ----------
function isFlickable(p) { return p.contentItem !== undefined && p.contentY !== undefined && p.flick !== undefined }

function scopeOf(item) {
    for (let p = item; p; p = p.parent)
        if (p.arrowScope !== undefined && p.arrowScope !== "") return p
    return null
}

function inside(item, scope) {
    for (let p = item; p; p = p.parent) if (p === scope) return true
    return false
}

// weggeschnitten (z. B. Inhalt eines zugeklappten Expanders)? Gescrollte Inhalte zählen nicht.
function clippedAway(n) {
    for (let p = n.parent; p; p = p.parent) {
        if (isFlickable(p)) return false
        if (p.clip) {
            const r = n.mapToItem(p, 0, 0)
            if (r.x + n.width <= 0 || r.y + n.height <= 0 || r.x >= p.width || r.y >= p.height) return true
        }
    }
    return false
}

function usable(n) {
    return n && n.visible && n.enabled && n.width > 0 && n.height > 0 && n.opacity > 0 && !clippedAway(n)
}

function rect(n) {
    const p = n.mapToItem(null, 0, 0)
    return { l: p.x, t: p.y, r: p.x + n.width, b: p.y + n.height, cx: p.x + n.width / 2, cy: p.y + n.height / 2 }
}

// Elemente mit "navigable: true" in einem Teilbaum (Roving-Gruppen: nur eins davon ist Tab-Station,
// die anderen sind nur per Pfeil erreichbar – wie die Navigationsleiste bei Windows)
function navigables(rootItem, out) {
    const kids = rootItem.children
    for (let i = 0; i < kids.length; i++) {
        const c = kids[i]
        if (!c.visible) continue
        if (c.navigable === true) out.push(c)
        navigables(c, out)
    }
    return out
}
function windowRoot(item) { let p = item; while (p.parent) p = p.parent; return p }

// alle fokussierbaren Elemente des Fensters (Tab-Kette + Roving-Elemente), ab "from"
function collect(from) {
    const out = []
    const start = from.nextItemInFocusChain(true)
    let n = start
    for (let i = 0; i < 3000 && n; i++, n = n.nextItemInFocusChain(true)) {
        if (i > 0 && n === start) break
        if (n !== from && usable(n) && out.indexOf(n) < 0) out.push(n)
    }
    for (const x of navigables(windowRoot(from), []))
        if (x !== from && usable(x) && out.indexOf(x) < 0) out.push(x)
    return out
}

// Roving-Gruppe: ist "item" die Tab-Station seines Bereichs? (aktiver Eintrag, sonst der erste)
// Ohne Bereich ist jedes Element eine Tab-Station.
//   activeFocusOnTab: active || activeFocus || FocusNav.rovingFirst(root)
function rovingFirst(item) {
    const scope = scopeOf(item.parent)
    if (!scope) return true
    const list = navigables(scope, [])
    if (list.some((x) => x.active === true)) return false
    return list.length > 0 && list[0] === item
}

// Tab aus einer Roving-Gruppe: zum nächsten Element außerhalb des Bereichs (Windows: Tab verlässt die Liste)
function tabOut(from, forward) {
    const scope = scopeOf(from)
    if (!scope) return false
    let n = from
    for (let i = 0; i < 3000; i++) {
        n = n.nextItemInFocusChain(forward)
        if (!n || n === from) return false
        if (usable(n) && !inside(n, scope)) return give(n, forward)
    }
    return false
}

const vert = { up: true, down: true }

function inDirection(f, c, dir) {
    switch (dir) {
    // Mitte weiter in Richtung und mindestens eine Kante auch (so geht z. B. Links vom
    // Schalter zurück auf die Zeile, in der er liegt, und Rechts von der Zeile auf den Schalter)
    case "down":  return c.cy > f.cy + 4 && (c.t > f.t + 1 || c.b > f.b + 1)
    case "up":    return c.cy < f.cy - 4 && (c.t < f.t - 1 || c.b < f.b - 1)
    case "right": return c.cx > f.cx + 4 && (c.l > f.l + 1 || c.r > f.r + 1)
    case "left":  return c.cx < f.cx - 4 && (c.l < f.l - 1 || c.r < f.r - 1)
    }
    return false
}

function overlaps(f, c, dir) {
    return vert[dir] ? Math.min(f.r, c.r) - Math.max(f.l, c.l) > 0
                     : Math.min(f.b, c.b) - Math.max(f.t, c.t) > 0
}

function score(f, c, dir, overlap) {
    const primary = dir === "down" ? c.t - f.b : dir === "up" ? f.t - c.b
                  : dir === "right" ? c.l - f.r : f.l - c.r
    const p = Math.max(0, primary)
    if (overlap) return p + 0.05 * (vert[dir] ? Math.abs(c.cx - f.cx) : Math.abs(c.cy - f.cy))
    const gap = vert[dir] ? Math.max(0, Math.max(f.l, c.l) - Math.min(f.r, c.r))
                          : Math.max(0, Math.max(f.t, c.t) - Math.min(f.b, c.b))
    return p + 2 * gap
}

// bestes Element in Richtung: zuerst mit Überlappung (gleiche Spalte/Zeile), sonst das nächste
function best(f, list, dir, allowLoose) {
    let pick = null, ps = Infinity, loose = null, ls = Infinity
    for (const n of list) {
        const c = rect(n)
        if (!inDirection(f, c, dir)) continue
        if (overlaps(f, c, dir)) {
            const s = score(f, c, dir, true)
            if (s < ps) { ps = s; pick = n }
        } else if (allowLoose) {
            const s = score(f, c, dir, false)
            if (s < ls) { ls = s; loose = n }
        }
    }
    return pick || loose
}

function topmost(list) {
    let pick = null, pr = null
    for (const n of list) {
        const c = rect(n)
        if (!pick || c.t < pr.t - 2 || (Math.abs(c.t - pr.t) <= 2 && c.l < pr.l)) { pick = n; pr = c }
    }
    return pick
}

// ---------- Fokus setzen + sichtbar machen ----------
function reveal(n) {
    for (let p = n.parent; p; p = p.parent) {
        if (!isFlickable(p) || p.contentHeight <= p.height) continue
        const top = n.mapToItem(p.contentItem, 0, 0).y
        const bottom = top + n.height
        const max = Math.max(0, p.contentHeight - p.height)
        if (top - 16 < p.contentY) p.contentY = Math.max(0, top - 16)
        else if (bottom + 16 > p.contentY + p.height) p.contentY = Math.min(max, bottom + 16 - p.height)
    }
}

function give(n, forward) {
    if (n._tabbed !== undefined) n._tabbed = true       // Eingabefeld: Text markieren (wie per Tab)
    n.forceActiveFocus(forward === false ? Qt.BacktabFocusReason : Qt.TabFocusReason)
    reveal(n)
    return true
}

// Bereich "scope" betreten – je nach arrowEnter
function enterScope(scope, list, f, dir) {
    const items = list.filter((n) => scopeOf(n) === scope)
    if (items.length === 0) return false
    const mode = scope.arrowEnter || "nearest"
    if (mode === "active") {
        const a = items.find((n) => n.active === true)
        if (a) return give(a)
    }
    if (mode === "first" || mode === "active") return give(topmost(items))
    const n = (dir && best(f, items, dir, true)) || topmost(items)
    return give(n)
}

function findScope(list, name) {
    for (const n of list) {
        const s = scopeOf(n)
        if (s && s.arrowScope === name) return s
    }
    return null
}

// ---------- Öffentlich ----------
// Fokus von "from" in Richtung "up" | "down" | "left" | "right" bewegen
function move(from, dir) {
    if (!from) return false
    const f = rect(from)
    const S = scopeOf(from)
    // Listen, in denen "from" liegt, nicht anspringen (der Fokus käme sonst sofort zurück)
    const all = collect(from).filter((x) => !(isView(x) && inside(from, x)))
    const link = S ? S["arrow" + dir.charAt(0).toUpperCase() + dir.slice(1)] : undefined

    let n = null
    if (S) {
        n = best(f, all.filter((x) => scopeOf(x) === S), dir, true)          // im eigenen Bereich
        if (n) return give(n, dir === "down" || dir === "right")
        if (link) {
            const t = findScope(all, link)
            if (t) return enterScope(t, all, f, dir)
        }
        if (vert[dir]) return false                                           // Bereichsrand
        n = best(f, all.filter((x) => scopeOf(x) !== S), dir, true)
    } else {
        n = best(f, all, dir, true)
    }
    if (!n) return false
    const T = scopeOf(n)
    if (T && T !== S && T.arrowEnter) return enterScope(T, all, f, dir)
    return give(n, dir === "down" || dir === "right")
}

// Tasten-Handler für Bedienelemente: Keys.onPressed: (e) => FocusNav.key(root, e)
function key(from, e) {
    if ((e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) && from.navigable === true &&
        !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
        const fwd = e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)
        if (tabOut(from, fwd)) { e.accepted = true; return true }
        return false
    }
    if (e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false
    const dir = e.key === Qt.Key_Up ? "up" : e.key === Qt.Key_Down ? "down"
              : e.key === Qt.Key_Left ? "left" : e.key === Qt.Key_Right ? "right" : ""
    if (dir === "" || !move(from, dir)) return false
    e.accepted = true
    return true
}

// alte Schnittstelle: Hoch/Runter
function vertical(from, forward) { return move(from, forward ? "down" : "up") }

// erstes (oberstes) Element in "scopeItem" fokussieren
function items(scopeItem) {
    const out = []
    const start = scopeItem.nextItemInFocusChain(true)
    let n = start
    for (let i = 0; i < 3000 && n; i++, n = n.nextItemInFocusChain(true)) {
        if (i > 0 && n === start) break
        if (usable(n) && inside(n, scopeItem) && out.indexOf(n) < 0) out.push(n)
    }
    return out
}
function first(scopeItem) {
    const n = topmost(items(scopeItem))
    return n ? give(n) : false
}
function indexIn(item, scopeItem) { return items(scopeItem).indexOf(item) }
function focusIndex(scopeItem, i) {
    const l = items(scopeItem)
    if (i < 0 || i >= l.length) return false
    return give(l[i])
}

// ---------- Für FocusRoot (Fenster-Ebene, wie der Browser bei HTML) ----------
function isText(it) { return it && it.cursorPosition !== undefined }   // TextInput/TextEdit/TextField …
function isView(it) { return it && it.currentIndex !== undefined && isFlickable(it) }   // ListView/GridView

// Enter/Leertaste auf einem fokussierten Element ohne eigene Tastenbehandlung:
// alles mit einem clicked()-Signal wird ausgelöst (Buttons aus QtQuick.Controls, eigene Buttons)
function activate(it) {
    if (!it || isText(it) || isView(it)) return false
    if (typeof it.clicked === "function") { it.clicked(); return true }
    return false
}

// Bekommt "it" einen Fokus-Ring von FocusRoot? Nur Elemente ohne eigenen Ring
// (Etude.Ui-Elemente setzen ownFocusRing: true), keine Textfelder und Listen.
function needsRing(it) {
    if (!it || !it.activeFocus || !it.visible || isText(it) || isView(it)) return false
    for (let p = it, i = 0; p && i < 3; p = p.parent, i++) if (p.ownFocusRing === true) return false
    if (it.visualFocus !== undefined) return it.visualFocus           // Controls: nur bei Tastatur-Fokus
    return it.activeFocusOnTab === true
}

// ---------- Listen mit eigener Auswahl (z. B. Prozesse) ----------
// Hoch/Runter/Pos1/Ende → neuer Index, übersprungen wird, was selectable(i) ablehnt.
// -1 = nicht behandelt bzw. Rand erreicht → e.accepted = false lassen (geht weiter zum Nachbarn).
//   Keys.onPressed: (e) => { const i = FocusNav.listKey(e, model.count, current, (j) => …)
//                            if (i >= 0) { select(i); e.accepted = true } }
function listKey(e, count, index, selectable) {
    if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return -1
    const ok = (i) => !selectable || selectable(i)
    let i = index, dir = 0
    if (e.key === Qt.Key_Down) dir = 1
    else if (e.key === Qt.Key_Up) dir = -1
    else if (e.key === Qt.Key_Home) { i = -1; dir = 1 }
    else if (e.key === Qt.Key_End) { i = count; dir = -1 }
    else return -1
    if (index < 0 && dir !== 0 && e.key !== Qt.Key_End) { i = -1; dir = 1 }   // noch nichts gewählt: erstes
    for (i += dir; i >= 0 && i < count; i += dir) if (ok(i)) return i
    return -1
}

// erster wählbarer Index (oder -1)
function firstIndex(count, selectable) {
    for (let i = 0; i < count; i++) if (!selectable || selectable(i)) return i
    return -1
}
