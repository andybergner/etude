#!/usr/bin/env python3
# Findet doppelt gesetzte Eigenschaften im selben QML-Objekt
# ("Property value set multiple times" – qmllint erkennt das nicht)
# und doppelte ids im selben Komponenten-Bereich ("id is not unique").
# Eigene Bereiche haben: die Datei, "Component { … }" und "delegate: …".
#   scripts/qml-dupcheck.py [ordner …]
import re, sys, pathlib

def check(path):
    stack, found = [{}], []
    for no, line in enumerate(path.read_text().splitlines(), 1):
        s = re.sub(r'"(?:\\.|[^"\\])*"', '""', line.split("//")[0])   # Strings/Kommentare raus
        m = re.match(r'\s*([A-Za-z_][\w.]*)\s*:(?!:)', s)
        if m and not s.strip().startswith(("case ", "default:")):
            key = m.group(1)
            if key in stack[-1]:
                found.append((no, key, stack[-1][key]))
            else:
                stack[-1][key] = no
        for ch in s:
            if ch == "{": stack.append({})
            elif ch == "}" and len(stack) > 1: stack.pop()
    return found

def check_ids(path):
    # Bereichs-Stapel: jeder Eintrag = (Klammertiefe beim Öffnen, {id: zeile})
    scopes, depth, found, pending = [(0, {})], 0, [], False
    for no, line in enumerate(path.read_text().splitlines(), 1):
        s = re.sub(r'"(?:\\.|[^"\\])*"', '""', line.split("//")[0])
        # Zeile in Stücke zwischen Klammern zerlegen, der Reihe nach abarbeiten
        for part in re.split(r'([{}])', s):
            if part == "{":
                depth += 1
                if pending: scopes.append((depth, {})); pending = False
            elif part == "}":
                if len(scopes) > 1 and scopes[-1][0] == depth: scopes.pop()
                depth -= 1
            else:
                if re.search(r'\bComponent\s*$|\bdelegate\s*:', part): pending = True
                for m in re.finditer(r'(?:^|;)\s*id\s*:\s*(\w+)\s*(?=;|$)', part):
                    ids = scopes[-1][1]
                    if m.group(1) in ids: found.append((no, m.group(1), ids[m.group(1)]))
                    else: ids[m.group(1)] = no
    return found

bad = 0
for root in sys.argv[1:] or ["."]:
    for f in sorted(pathlib.Path(root).rglob("*.qml")):
        for no, key, first in check(f):
            print(f"{f}:{no}: '{key}' schon in Zeile {first} gesetzt"); bad += 1
        for no, key, first in check_ids(f):
            print(f"{f}:{no}: id '{key}' gibt es schon in Zeile {first}"); bad += 1
sys.exit(1 if bad else 0)
