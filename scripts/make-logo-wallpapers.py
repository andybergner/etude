#!/usr/bin/env python3
# Etude-Hintergründe mit Logo in der Mitte (Stil: schlichte Fläche + Zeichen).
# Logo = eckiges O (Ring), diagonal geteilt – wie branding/etude-mark.svg.
from PIL import Image, ImageDraw
import os

W, H = 2560, 1440
SS = 2                                   # Supersampling gegen Treppchen
OUT = os.path.join(os.path.dirname(__file__), "..", "branding", "wallpapers")

def logo_wallpaper(name, bg, top, bottom, size=0.28):
    w, h = W * SS, H * SS
    img = Image.new("RGB", (w, h), bg)
    s = h * size                         # Kantenlänge des Zeichens
    cx, cy = w / 2, h / 2
    x0, y0 = cx - s / 2, cy - s / 2
    hole = s * 138.6 / 271               # Verhältnis aus dem SVG
    gap = s * 18 / 271                   # Breite des diagonalen Schnitts

    def ring(color):
        m = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(m)
        d.rectangle([x0, y0, x0 + s, y0 + s], fill=255)
        hx, hy = cx - hole / 2, cy - hole / 2
        d.rectangle([hx, hy, hx + hole, hy + hole], fill=0)
        return m

    base = ring(None)
    # obere/linke Hälfte: Dreieck oben links, untere/rechte: unten rechts – mit Lücke
    up = Image.new("L", (w, h), 0)
    ImageDraw.Draw(up).polygon([(x0, y0), (x0 + s - gap / 2, y0), (x0, y0 + s - gap / 2)], fill=255)
    lo = Image.new("L", (w, h), 0)
    ImageDraw.Draw(lo).polygon([(x0 + s, y0 + gap / 2), (x0 + s, y0 + s), (x0 + gap / 2, y0 + s)], fill=255)

    from PIL import ImageChops
    img.paste(top, mask=ImageChops.multiply(base, up))
    img.paste(bottom, mask=ImageChops.multiply(base, lo))
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    print("->", name)

logo_wallpaper("etude-logo-grau",     "#28292d", "#d4d4d8", "#d4d4d8")
logo_wallpaper("etude-logo-schwarz",  "#09090b", "#3f3f46", "#3f3f46")
logo_wallpaper("etude-logo-zink",     "#18181b", "#e4e4e7", "#71717a")
logo_wallpaper("etude-logo-nacht",    "#1a1b26", "#c0caf5", "#7aa2f7")
logo_wallpaper("etude-logo-hell",     "#f4f4f5", "#27272a", "#27272a")
