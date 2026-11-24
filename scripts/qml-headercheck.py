#!/usr/bin/env python3
"""Findet QML-Dateien, deren Kopf vor dem letzten import eine Zeile mit '{' hat.

Quickshells Scanner liest imports nur bis zur ersten Zeile mit '{' (auch in Kommentaren).
Alles danach wird ignoriert – Ordner-Imports werden dann nicht eingelesen und ihre Typen
sind "not a type". Aufruf: scripts/qml-headercheck.py [ordner …]
"""
import sys, pathlib

bad = 0
roots = sys.argv[1:] or ["shell", "apps", "qml", "greeter", "docs/examples"]
for root in roots:
    for f in sorted(pathlib.Path(root).rglob("*.qml")):
        lines = f.read_text(errors="ignore").splitlines()
        last_import = max((i for i, l in enumerate(lines) if l.strip().startswith("import ")), default=-1)
        for i, l in enumerate(lines[:last_import]):
            if "{" in l:
                print(f"{f}:{i + 1}: '{{' vor dem letzten import – Quickshell überliest die imports danach")
                bad += 1
                break
print(f"{bad} Datei(en) mit Problem" if bad else "ok")
sys.exit(1 if bad else 0)
