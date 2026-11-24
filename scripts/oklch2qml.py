#!/usr/bin/env python3
"""Rechnet shadcn-Farben (oklch) in QML-Farben um.

QML erwartet #RRGGBB oder mit Transparenz #AARRGGBB (Alpha ZUERST, anders als CSS).
Nutzung: oklch2qml.py "oklch(0.141 0.005 285.823)"  ->  #09090b
"""
import math, re, sys

def oklch_to_srgb(L, C, H):
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    def enc(x):
        x = max(0.0, min(1.0, x))
        return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
    return [round(enc(c) * 255) for c in (r, g, bl)]

def to_qml(css):
    m = re.match(r"oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*(?:/\s*([\d.]+)%?)?\s*\)", css.strip())
    if not m:
        raise ValueError(css)
    L, C, H = map(float, m.group(1, 2, 3))
    r, g, b = oklch_to_srgb(L, C, H)
    hexrgb = f"{r:02x}{g:02x}{b:02x}"
    if m.group(4):
        a = round(float(m.group(4)) / 100 * 255)
        return f"#{a:02x}{hexrgb}"
    return f"#{hexrgb}"

if __name__ == "__main__":
    for arg in sys.argv[1:]:
        print(to_qml(arg))
