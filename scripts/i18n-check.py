#!/usr/bin/env python3
"""Übersetzungen von Etude prüfen.

Alle Texte liegen wie bei Omarchy in default/i18n/<sprache>/<bereich>.json – en/ ist die Grundlage.
Im Code: Translations { id: tr; domain: "files" }, tr.t("key"), tr.tn("key", n), I18n.t("common.key")
(gemeinsame Texte = Bereich „ui“).

Prüft:
  * gültiges JSON, flache Kataloge (Text oder Mehrzahl-Objekt mit "other")
  * jeder im Code benutzte Schlüssel steht in der en.json seines Moduls        (Fehler)
  * Platzhalter %1, %2 … sind in jeder Sprache dieselben wie im Englischen      (Fehler)
  * Schlüssel, die es nur in einer Übersetzung gibt                            (Fehler)
  * fehlende Übersetzungen je Sprache, unbenutzte Schlüssel                    (Hinweis)
  * --literals: Texte, die noch fest im Code stehen (für die Umstellung)

Aufruf (im Repo):  python3 scripts/i18n-check.py [--literals] [--verbose]
Rückgabe 1 bei Fehlern.
"""
import json, os, re, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
I18N = os.path.join(ROOT, "default", "i18n")
COMMON = "ui"
SKIP = {".git", "node_modules", "scripts", "default"}
PH = re.compile(r"%\d+")
CALL = re.compile(r"\b([A-Za-z_]\w*)\.(tn?)\(\s*\"([^\"]+)\"\s*[,)]")
TR_DECL = re.compile(r"Translations\s*\{[^}]*?\bid:\s*(\w+)[^}]*?domain:\s*\"([^\"]+)\"", re.S)
TR_DECL2 = re.compile(r"Translations\s*\{[^}]*?domain:\s*\"([^\"]+)\"[^}]*?\bid:\s*(\w+)", re.S)
TR_PROP = re.compile(r"property\s+Translations\s+(\w+)\s*:\s*Translations\s*\{[^}]*?domain:\s*\"([^\"]+)\"", re.S)
TR_ANY = re.compile(r"Translations\s*\{[^}]*?domain:\s*\"([^\"]+)\"", re.S)
LITERAL = re.compile(r"\b(text|label|desc|description|title|placeholder|tip|hint|subtitle|tooltip)\s*:\s*\"([^\"]*[A-Za-zÄÖÜäöüß]{2,}[^\"]*)\"")

errors, notes = [], []
def rel(p): return os.path.relpath(p, ROOT)
def path_domain(path):
    """Bereich aus dem Ort der Datei (apps/<app>, shell/modules/<modul>, qml/Etude/<Modul>)."""
    parts = rel(path).split(os.sep)
    if parts[0] == "apps" and len(parts) > 2: return parts[1]
    if parts[:2] == ["shell", "modules"] and len(parts) > 3: return parts[2]
    if parts[0] == "qml" and len(parts) > 3: return parts[2].lower()
    return None
def catfile(cat, lang): return f"default/i18n/{lang}/{cat}.json"

def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        errors.append(f"{rel(path)}: kein gültiges JSON ({e})")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{rel(path)}: muss ein Objekt sein")
        return {}
    for k, v in data.items():
        if isinstance(v, dict):
            if "other" not in v:
                errors.append(f"{rel(path)}: „{k}“ – Mehrzahl ohne \"other\"")
        elif not isinstance(v, str):
            errors.append(f"{rel(path)}: „{k}“ – Wert muss Text oder Mehrzahl-Objekt sein")
    return data

def placeholders(v):
    texts = v.values() if isinstance(v, dict) else [v]
    return sorted(set(m for t in texts if isinstance(t, str) for m in PH.findall(t)))

# ---- Kataloge einlesen: default/i18n/<sprache>/<bereich>.json ----
catalogs = {}          # bereich -> { sprache: daten }
for lang in sorted(os.listdir(I18N)) if os.path.isdir(I18N) else []:
    ldir = os.path.join(I18N, lang)
    if not os.path.isdir(ldir):
        continue
    for fn in sorted(os.listdir(ldir)):
        if fn.endswith(".json"):
            catalogs.setdefault(fn[:-5], {})[lang] = load(os.path.join(ldir, fn))
for cat, langs in catalogs.items():
    if "en" not in langs:
        errors.append(f"{catfile(cat, 'en')} fehlt (Grundlage für „{cat}“)")

# ---- Code durchsuchen ----
used = {c: set() for c in catalogs}
literals = []
for dirpath, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP and d != "i18n"]
    for fn in files:
        if not fn.endswith((".qml", ".js")):
            continue
        path = os.path.join(dirpath, fn)
        src = open(path, encoding="utf-8").read()
        code = re.sub(r"^\s*//.*$", "", src, flags=re.M)
        ids = {}
        for m in TR_DECL.finditer(code):
            ids[m.group(1)] = m.group(2)
        for m in TR_DECL2.finditer(code):
            ids[m.group(2)] = m.group(1)
        for m in TR_PROP.finditer(code):
            ids[m.group(1)] = m.group(2)
        decl = TR_ANY.findall(code)
        near = decl[0] if len(set(decl)) == 1 else path_domain(path)
        for m in CALL.finditer(code):
            name, key = m.group(1), m.group(3)
            if name == "I18n" or (name == "common" and fn == "I18n.qml"):
                cat = COMMON
            elif name in ids:
                cat = ids[name]
            elif name in ("tr", "strings"):
                cat = near
            else:
                continue
            line = src[:m.start()].count("\n") + 1
            if not cat or cat not in catalogs:
                errors.append(f"{rel(path)}:{line}: kein Katalog für „{key}“ gefunden")
                continue
            used[cat].add(key)
            if key not in catalogs[cat].get("en", {}):
                errors.append(f"{rel(path)}:{line}: „{key}“ fehlt in {catfile(cat, 'en')}")
        # Schlüssel, die indirekt benutzt werden, z. B. tr.t(a ? "menus.connected" : "menus.paired")
        for m in re.finditer(r'"([a-z][A-Za-z0-9]*\.[A-Za-z0-9.]+)"', code):
            for cat in set(ids.values()) | {near, COMMON}:
                if cat in catalogs and m.group(1) in catalogs[cat].get("en", {}):
                    used[cat].add(m.group(1))
        # zusammengesetzte Schlüssel, z. B. tr.t("nav." + id): alle Schlüssel mit diesem Anfang gelten als benutzt
        for m in re.finditer(r'"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)*\.)"\s*\+', code):
            for cat in set(ids.values()) | {near, COMMON}:
                if cat in catalogs:
                    used[cat].update(k for k in catalogs[cat].get("en", {}) if k.startswith(m.group(1)))
        for m in LITERAL.finditer(code):
            literals.append((rel(path), code[:m.start()].count("\n") + 1, m.group(2)))

# ---- Kataloge vergleichen ----
for cat, langs in sorted(catalogs.items()):
    en = langs.get("en", {})
    for lang, data in langs.items():
        if lang == "en":
            continue
        for k, v in data.items():
            if k not in en:
                errors.append(f"{catfile(cat, lang)}: „{k}“ gibt es nicht in {catfile(cat, 'en')}")
            elif placeholders(v) != placeholders(en[k]):
                errors.append(f"{catfile(cat, lang)}: „{k}“ – Platzhalter {placeholders(v)} statt {placeholders(en[k])}")
        missing = [k for k in en if k not in data]
        if missing:
            notes.append(f"{catfile(cat, lang)}: {len(missing)} von {len(en)} Texten fehlen" +
                         (": " + ", ".join(missing[:8]) + (" …" if len(missing) > 8 else "") if "--verbose" in sys.argv else ""))
    unused = sorted(k for k in en if k not in used[cat]) if cat != COMMON else []
    if unused:
        notes.append(f"{catfile(cat, 'en')}: {len(unused)} unbenutzt" + (": " + ", ".join(unused) if "--verbose" in sys.argv else ""))

# ---- Ausgabe ----
for e in errors:
    print("FEHLER   " + e)
for n in notes:
    print("Hinweis  " + n)
if "--literals" in sys.argv:
    for f, l, t in literals:
        print(f"Text     {f}:{l}: \"{t}\"")
byfile = {}
for f, _, _ in literals:
    byfile[f] = byfile.get(f, 0) + 1
print(f"\n{len(catalogs)} Kataloge, {sum(len(u) for u in used.values())} benutzte Schlüssel, "
      f"{len(errors)} Fehler, noch {len(literals)} feste Texte in {len(byfile)} Dateien"
      + ("" if "--literals" in sys.argv else " (Details: --literals)"))
sys.exit(1 if errors else 0)
