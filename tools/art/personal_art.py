#!/usr/bin/env python3
"""Art for the personal stories of stage 20 (drawn in code, no asset pack).

    python3 tools/art/personal_art.py

  world_hd/props/alchemy_still.png      — Lira's copper still with a flask;
  world_hd/sky_shop_lastochka.png       — Bran's flying shop «Ласточка»;
  props/keeper_alchemy_notes.png (+ HD) — the Keeper alchemist's notebook.
HD art is drawn at 4× and downsampled (smooth, like the HD world), shown at
scale 0.5. Entries go to assets/art_manifest.json.
"""
from __future__ import annotations

import json
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
SS = 4
OUTLINE = (34, 24, 30, 255)


def hd_canvas(w: int, h: int):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def finish(im: Image.Image, w: int, h: int, outline: bool = True) -> Image.Image:
    small = im.resize((w, h), Image.LANCZOS)
    if not outline:
        return small
    # A soft dark rim, as the HD props have.
    alpha = small.split()[3]
    grown = alpha.filter(ImageFilter.MaxFilter(3))
    rim = Image.new("RGBA", small.size, OUTLINE)
    rim.putalpha(grown.point(lambda a: int(a * 0.85)))
    rim.alpha_composite(small)
    return rim


def S(*v):
    return [x * SS for x in v]


def shade_ellipse(d, box, base, light, dark, steps=10):
    x0, y0, x1, y1 = box
    d.ellipse(S(x0, y0, x1, y1), fill=dark)
    for i in range(steps):
        t = i / steps
        inset = (x1 - x0) * 0.08 * t
        col = tuple(int(dark[k] + (base[k] - dark[k]) * min(1, t * 1.6)) for k in range(3)) + (255,)
        d.ellipse(S(x0 + inset, y0 + inset * 0.8, x1 - inset * 2.2, y1 - inset * 2.0), fill=col)
    lx, ly = x0 + (x1 - x0) * 0.22, y0 + (y1 - y0) * 0.18
    d.ellipse(S(lx, ly, lx + (x1 - x0) * 0.22, ly + (y1 - y0) * 0.2), fill=light)


def alchemy_still() -> Image.Image:
    w, h = 64, 76
    im, d = hd_canvas(w, h)
    copper, copper_l, copper_d = (196, 108, 58), (246, 178, 116), (120, 58, 36)
    wood, wood_d = (132, 88, 52), (86, 54, 34)
    # Shadow.
    d.ellipse(S(8, 66, 58, 75), fill=(0, 0, 0, 70))
    # Stand and firebox.
    d.rectangle(S(12, 54, 40, 70), fill=wood_d)
    d.rectangle(S(13, 55, 39, 68), fill=wood)
    d.rectangle(S(18, 60, 34, 68), fill=(40, 26, 24, 255))
    for i, col in enumerate([(255, 214, 90), (255, 140, 40), (220, 70, 30)]):
        d.polygon(S(20 + i, 68, 26, 61 + i * 1.5, 32 - i, 68), fill=col + (255,))
    # The pot.
    shade_ellipse(d, (8, 26, 44, 60), copper, copper_l + (255,), copper_d + (255,))
    d.rectangle(S(10, 40, 42, 43), fill=copper_d + (255,))
    for x in (13, 19, 25, 31, 37):
        d.ellipse(S(x, 40.5, x + 2, 42.5), fill=copper_l + (255,))
    # Neck and dome.
    d.rectangle(S(21, 16, 31, 28), fill=copper)
    d.rectangle(S(22, 16, 24, 28), fill=copper_l)
    shade_ellipse(d, (17, 8, 35, 22), copper, copper_l + (255,), copper_d + (255,))
    # Swan neck to the coil.
    for i in range(30):
        t = i / 29
        x = 33 + 18 * t
        y = 14 + 10 * math.sin(t * math.pi * 0.9)
        d.ellipse(S(x - 2, y - 2, x + 2, y + 2), fill=copper_d)
        d.ellipse(S(x - 1.4, y - 1.8, x + 1.2, y + 0.6), fill=copper_l if i % 3 else copper)
    # The coil in a barrel.
    d.rectangle(S(46, 30, 60, 62), fill=wood_d)
    d.rectangle(S(47, 31, 59, 61), fill=wood)
    for y in (36, 46, 56):
        d.rectangle(S(46, y, 60, y + 2), fill=(70, 70, 76, 255))
    for k in range(3):
        y = 30 - k * 0.0
        d.arc(S(45, 23 + k * 3, 61, 33 + k * 3), 180, 360, fill=copper_l, width=SS * 2)
    # The flask on top: bubbling green.
    d.ellipse(S(47, 8, 61, 24), fill=(150, 220, 200, 200))
    d.ellipse(S(48, 13, 60, 24), fill=(120, 230, 110, 230))
    d.rectangle(S(52, 2, 56, 10), fill=(170, 220, 210, 210))
    d.ellipse(S(50, 14, 53, 17), fill=(230, 255, 210, 255))
    d.ellipse(S(55, 18, 57, 20), fill=(230, 255, 210, 255))
    d.ellipse(S(49, 10, 51, 13), fill=(255, 255, 255, 220))
    return finish(im, w, h)


def lastochka() -> Image.Image:
    w, h = 132, 120
    im, d = hd_canvas(w, h)
    # Balloon.
    env, env_l, env_d = (214, 88, 74), (250, 160, 130), (140, 46, 46)
    shade_ellipse(d, (22, 2, 110, 58), env, env_l + (255,), env_d + (255,), 14)
    # Gores: seams of the envelope, all inside its outline.
    for half in (14, 29):
        d.ellipse(S(66 - half, 3, 66 + half, 57), outline=(120, 40, 40, 150), width=SS)
    d.line(S(66, 3, 66, 57), fill=(120, 40, 40, 150), width=SS)
    d.chord(S(22, 2, 110, 58), 160, 200, fill=(242, 206, 120, 255))
    d.chord(S(22, 2, 110, 58), 340, 20, fill=(242, 206, 120, 255))
    d.rectangle(S(30, 27, 102, 31), fill=(242, 206, 120, 255))
    # Ropes.
    for x0, x1 in ((30, 40), (50, 54), (82, 78), (102, 92)):
        d.line(S(x0, 46, x1, 76), fill=(90, 70, 52, 255), width=SS)
    # The barrel-hull.
    hull, hull_l, hull_d = (164, 112, 64), (214, 164, 104), (98, 62, 38)
    d.ellipse(S(28, 74, 104, 112), fill=hull_d)
    d.ellipse(S(30, 74, 102, 108), fill=hull)
    d.rectangle(S(30, 74, 102, 90), fill=hull)
    for y in (82, 94):
        d.rectangle(S(29, y, 103, y + 2.4), fill=(84, 84, 92, 255))
    for x in range(34, 100, 9):
        d.line(S(x, 76, x, 104), fill=hull_l + (120,), width=SS)
    d.ellipse(S(40, 98, 92, 110), fill=hull_d)
    # Striped awning.
    stripes = [(250, 236, 210), (60, 132, 160)]
    for i in range(8):
        x = 28 + i * 9.5
        d.polygon(S(x, 66, x + 9.5, 66, x + 10.5, 76, x - 1, 76), fill=stripes[i % 2] + (255,))
    for i in range(8):
        x = 28 + i * 9.5
        d.pieslice(S(x - 1, 72, x + 10.5, 80), 0, 180, fill=stripes[i % 2] + (255,))
    # Crates, apples and a lantern.
    d.rectangle(S(36, 64, 50, 75), fill=(178, 130, 76, 255))
    d.rectangle(S(37, 65, 49, 74), fill=(204, 156, 96, 255))
    for x, y in ((39, 63), (43, 62), (47, 63)):
        d.ellipse(S(x - 2.4, y - 2.4, x + 2.4, y + 2.4), fill=(214, 52, 46, 255))
    d.rectangle(S(84, 62, 96, 75), fill=(150, 104, 60, 255))
    d.line(S(100, 70, 100, 84), fill=(70, 60, 50, 255), width=SS)
    d.ellipse(S(96, 82, 104, 92), fill=(255, 210, 110, 255))
    # A sign: a swallow.
    d.rectangle(S(56, 84, 76, 96), fill=(240, 226, 196, 255))
    d.polygon(S(60, 90, 66, 87, 72, 89, 66, 91, 63, 94), fill=(40, 52, 78, 255))
    # Propeller at the stern.
    d.ellipse(S(102, 84, 108, 90), fill=(90, 90, 96, 255))
    d.polygon(S(105, 87, 112, 78, 114, 80), fill=(150, 150, 160, 255))
    d.polygon(S(105, 87, 112, 96, 114, 94), fill=(150, 150, 160, 255))
    return finish(im, w, h)


def notes(w: int, h: int) -> Image.Image:
    im, d = hd_canvas(w, h)
    k = w / 32
    d.ellipse(S(4 * k, 24 * k, 28 * k, 31 * k), fill=(0, 0, 0, 60))
    # Glow.
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(S(2 * k, 4 * k, 30 * k, 30 * k), fill=(180, 255, 200, 90))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(4 * SS * k)))
    d = ImageDraw.Draw(im)
    # An open notebook with a bark cover.
    d.polygon(S(3 * k, 14 * k, 16 * k, 18 * k, 29 * k, 14 * k, 29 * k, 26 * k, 16 * k, 29 * k, 3 * k, 26 * k), fill=(110, 76, 46, 255))
    d.polygon(S(4 * k, 12 * k, 16 * k, 16 * k, 16 * k, 27 * k, 4 * k, 23 * k), fill=(246, 236, 206, 255))
    d.polygon(S(16 * k, 16 * k, 28 * k, 12 * k, 28 * k, 23 * k, 16 * k, 27 * k), fill=(236, 224, 190, 255))
    for i in range(4):
        y = 15 + i * 2.6
        d.line(S(6 * k, (y + 0.6) * k, 14 * k, (y + 2.6) * k), fill=(90, 80, 120, 255), width=max(1, int(SS * k * 0.6)))
        d.line(S(18 * k, (y + 2.6) * k, 26 * k, (y + 0.6) * k), fill=(90, 80, 120, 255), width=max(1, int(SS * k * 0.6)))
    # A little drawn flask and notes.
    d.ellipse(S(20 * k, 19 * k, 24 * k, 23 * k), outline=(60, 140, 90, 255), width=max(1, int(SS * k * 0.6)))
    return finish(im, w, h)


def save(rel: str, img: Image.Image, origin, scale: float | None, manifest: dict) -> None:
    path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    entry = {"size": [img.width, img.height], "origin": list(origin)}
    if scale is not None:
        entry["scale"] = scale
    manifest[rel] = entry
    print("  ", rel, img.size)


def main() -> int:
    manifest_path = ASSETS / "art_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    still = alchemy_still()
    save("world_hd/props/alchemy_still.png", still, (still.width // 2, still.height - 4), 0.5, manifest)
    ship = lastochka()
    save("world_hd/sky_shop_lastochka.png", ship, (ship.width // 2, ship.height // 2), 0.5, manifest)
    small = notes(16, 16)
    save("props/keeper_alchemy_notes.png", small, (8, 14), None, manifest)
    big = notes(32, 32)
    save("world_hd/props/keeper_alchemy_notes.png", big, (16, 28), 0.5, manifest)
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
