#!/usr/bin/env python3
"""Hilfsskript für die Umstellung: listet sichtbare Texte (Literale) in QML/JS-Dateien.
Aufruf: python3 scripts/i18n-scan.py <ordner|datei>…   Ausgabe: datei:zeile<TAB>text"""
import os, re, sys
SKIP = re.compile(r"hl\.dsp|\$\{|\\x1f|^file:|^#|Theme\.|' \+|url\(|data:|printf|^/|\.(svg|png|sh|json|qml|desktop)$")
def scan(p):
    for n, line in enumerate(open(p, encoding="utf-8"), 1):
        st = line.strip()
        if st.startswith(("import", "//", "*", ".import", ".pragma")): continue
        code = re.sub(r'(^|[^:"])//[^"]*$', r"\1", line)
        if "console." in code: continue
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', code):
            s = m.group(1)
            if not re.search(r"[A-Za-zÄÖÜäöüß]{2,}", s): continue
            if re.fullmatch(r"[A-Za-z0-9_.:/\-#@*%+=,]+", s) and not re.search(r"[A-ZÄÖÜ][a-zäöü]", s): continue
            if SKIP.search(s) or re.fullmatch(r"[a-z]+(\.[A-Za-z0-9]+)+", s): continue
            if re.search(r"tr\.tn?\(\s*$|I18n\.tn?\(\s*$", code[:m.start()]): continue
            print(f"{p}:{n}\t{s}")
for a in sys.argv[1:]:
    if os.path.isfile(a): scan(a)
    else:
        for dp, ds, fs in os.walk(a):
            ds[:] = [d for d in ds if d != "i18n"]
            for f in sorted(fs):
                if f.endswith((".qml", ".js")): scan(os.path.join(dp, f))
