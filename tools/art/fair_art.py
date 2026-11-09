#!/usr/bin/env python3
"""Art of the village fair (stage 20), drawn in code — no asset pack.

    python3 tools/art/fair_art.py

  world_hd/props/fair_booth.png    — the prize booth (striped tent, prizes);
  world_hd/props/fair_gallery.png  — the shooting gallery counter;
  world_hd/props/fair_target.png   — a straw target on a stick;
  world_hd/props/fair_maypole.png  — the ribbon pole with a flower wreath.
Drawn at 4× and downsampled like tools/art/personal_art.py; shown at 0.5.
"""
from __future__ import annotations

import json
import math

from PIL import Image, ImageDraw

from personal_art import ASSETS, S, finish, hd_canvas, save, shade_ellipse

RED, CREAM, GOLD = (206, 64, 58), (250, 236, 206), (238, 186, 72)
WOOD, WOOD_L, WOOD_D = (150, 100, 58), (200, 150, 96), (92, 60, 36)


def stripes_roof(d, x0, x1, top, bottom, colors, count=7, scallop=True):
    width = (x1 - x0) / count
    peak = (x0 + x1) / 2
    for i in range(count):
        a, b = x0 + i * width, x0 + (i + 1) * width
        col = colors[i % len(colors)] + (255,)
        d.polygon(S(peak, top, peak, top, b, bottom, a, bottom), fill=col)
        if scallop:
            d.pieslice(S(a, bottom - width * 0.5, b, bottom + width * 0.5), 0, 180, fill=col)


def booth() -> Image.Image:
    w, h = 104, 100
    im, d = hd_canvas(w, h)
    d.ellipse(S(8, 88, 96, 99), fill=(0, 0, 0, 60))
    # Posts.
    for x in (14, 86):
        d.rectangle(S(x, 30, x + 5, 92), fill=WOOD_D)
        d.rectangle(S(x + 1, 30, x + 3, 92), fill=WOOD)
    # Back cloth and counter.
    d.rectangle(S(18, 40, 86, 70), fill=(120, 60, 70, 255))
    d.rectangle(S(10, 66, 94, 92), fill=WOOD_D)
    d.rectangle(S(11, 67, 93, 90), fill=WOOD)
    for x in range(14, 92, 8):
        d.line(S(x, 68, x, 89), fill=WOOD_L + (140,), width=SS_W())
    d.rectangle(S(8, 63, 96, 68), fill=WOOD_L)
    # Prizes on the counter: candy cocks, a wreath, jars, a star.
    for i, x in enumerate((20, 30)):
        d.line(S(x, 63, x, 52), fill=(230, 220, 200, 255), width=SS_W())
        d.ellipse(S(x - 4, 44, x + 4, 54), fill=(232, 70, 60, 255) if i == 0 else (240, 170, 50, 255))
        d.ellipse(S(x - 2, 46, x, 48), fill=(255, 240, 220, 255))
    shade_ellipse(d, (40, 48, 58, 64), (90, 160, 80), (180, 230, 140, 255), (40, 90, 40, 255))
    d.ellipse(S(45, 53, 53, 59), fill=(120, 60, 70, 255))
    for k in range(6):
        a = k * math.pi / 3
        d.ellipse(S(49 + math.cos(a) * 7 - 2, 56 + math.sin(a) * 6 - 2, 49 + math.cos(a) * 7 + 2, 56 + math.sin(a) * 6 + 2),
                  fill=[(255, 120, 150), (255, 230, 90), (180, 140, 255)][k % 3] + (255,))
    for i, col in enumerate([(120, 200, 230), (240, 140, 200)]):
        x = 64 + i * 9
        d.rectangle(S(x, 50, x + 7, 63), fill=col + (220,))
        d.rectangle(S(x + 1, 48, x + 6, 50), fill=WOOD_D)
    d.polygon(S(86, 46, 88, 51, 93, 51, 89, 54, 91, 59, 86, 56, 81, 59, 83, 54, 79, 51, 84, 51), fill=GOLD + (255,))
    # Roof.
    stripes_roof(d, 4, 100, 6, 36, [RED, CREAM])
    d.ellipse(S(48, 2, 56, 10), fill=GOLD)
    # Pennant on top.
    d.line(S(52, 2, 52, -6), fill=WOOD_D, width=SS_W())
    return finish(im, w, h)


def SS_W() -> int:
    return 4


def gallery() -> Image.Image:
    w, h = 108, 84
    im, d = hd_canvas(w, h)
    d.ellipse(S(6, 72, 102, 83), fill=(0, 0, 0, 60))
    # Counter.
    d.rectangle(S(6, 46, 102, 76), fill=WOOD_D)
    d.rectangle(S(7, 47, 101, 74), fill=WOOD)
    for x in range(10, 100, 9):
        d.line(S(x, 48, x, 73), fill=WOOD_L + (130,), width=SS_W())
    d.rectangle(S(4, 42, 104, 48), fill=WOOD_L)
    # Crossbow and arrows on the counter.
    d.line(S(16, 40, 40, 36), fill=WOOD_D, width=SS_W() * 2)
    d.arc(S(30, 28, 44, 46), 280, 80, fill=(90, 90, 100, 255), width=SS_W() * 2)
    for k in range(3):
        d.line(S(60 + k * 6, 41, 70 + k * 6, 30), fill=(230, 220, 200, 255), width=SS_W())
        d.polygon(S(70 + k * 6, 30, 72 + k * 6, 31, 70 + k * 6, 33), fill=(200, 60, 50, 255))
    # Sign board with a target on posts.
    for x in (20, 84):
        d.rectangle(S(x, 4, x + 4, 44), fill=WOOD_D)
    d.rectangle(S(16, 2, 92, 20), fill=(240, 224, 190, 255))
    d.rectangle(S(16, 2, 92, 4), fill=RED)
    d.rectangle(S(16, 18, 92, 20), fill=RED)
    for r, col in ((7, RED), (5, CREAM), (3, RED), (1.4, CREAM)):
        d.ellipse(S(54 - r, 11 - r, 54 + r, 11 + r), fill=col + (255,))
    for x in (28, 80):
        d.polygon(S(x - 5, 11, x + 3, 11, x + 3, 9, x + 6, 12, x + 3, 15, x + 3, 13, x - 5, 13), fill=(80, 60, 50, 255))
    return finish(im, w, h)


def target() -> Image.Image:
    w, h = 40, 60
    im, d = hd_canvas(w, h)
    d.ellipse(S(10, 54, 30, 59), fill=(0, 0, 0, 60))
    d.rectangle(S(18, 30, 22, 57), fill=WOOD_D)
    d.rectangle(S(19, 30, 21, 57), fill=WOOD)
    # Straw disc.
    shade_ellipse(d, (3, 3, 37, 37), (226, 188, 98), (250, 226, 150, 255), (170, 128, 58, 255))
    for r, col in ((12, RED), (9, CREAM), (6, RED), (3, CREAM)):
        d.ellipse(S(20 - r, 20 - r, 20 + r, 20 + r), fill=col + (255,))
    for k in range(10):
        a = k * math.pi / 5
        d.line(S(20 + math.cos(a) * 14, 20 + math.sin(a) * 14, 20 + math.cos(a) * 17, 20 + math.sin(a) * 17), fill=(250, 226, 150, 255), width=SS_W())
    return finish(im, w, h)


def maypole() -> Image.Image:
    w, h = 40, 156
    im, d = hd_canvas(w, h)
    d.ellipse(S(8, 148, 32, 155), fill=(0, 0, 0, 60))
    d.rectangle(S(17, 14, 23, 152), fill=(236, 226, 206, 255))
    for y in range(18, 150, 10):
        d.polygon(S(17, y, 23, y - 4, 23, y, 17, y + 4), fill=(206, 64, 58, 255))
    d.rectangle(S(17, 14, 18.5, 152), fill=(255, 255, 255, 120))
    # Wreath on top.
    for k in range(14):
        a = k * math.pi * 2 / 14
        x, y = 20 + math.cos(a) * 13, 16 + math.sin(a) * 5
        d.ellipse(S(x - 4, y - 3, x + 4, y + 3), fill=(80, 150, 70, 255))
    for k in range(7):
        a = k * math.pi * 2 / 7 + 0.3
        x, y = 20 + math.cos(a) * 13, 16 + math.sin(a) * 5
        d.ellipse(S(x - 2.4, y - 2.4, x + 2.4, y + 2.4), fill=[(255, 120, 150), (255, 230, 90), (180, 140, 255), (255, 255, 255)][k % 4] + (255,))
    d.ellipse(S(16, 2, 24, 10), fill=GOLD)
    return finish(im, w, h)


def main() -> int:
    manifest_path = ASSETS / "art_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for name, img, origin in [
        ("fair_booth", booth(), None), ("fair_gallery", gallery(), None),
        ("fair_target", target(), None), ("fair_maypole", maypole(), None),
    ]:
        save(f"world_hd/props/{name}.png", img, origin or (img.width // 2, img.height - 4), 0.5, manifest)
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
