"""The Keepers' sky ship «Ветрокрыл» (Этап 16), drawn procedurally — no
asset-pack sources. Two HD sprites (2× world scale, shown at 0.5):

    assets/world_hd/sky_ship.png        — the repaired airship (side view)
    assets/world_hd/sky_ship_wreck.png  — the wreck on the Salt Coast

    python3 tools/art/ship.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "world_hd"
SS = 4  # supersampling factor; drawn at 4× the final HD size

OUTLINE = (42, 28, 24, 255)
WOOD_DARK = (92, 56, 34, 255)
WOOD = (140, 88, 52, 255)
WOOD_LIGHT = (184, 124, 74, 255)
GOLD = (232, 186, 82, 255)
GOLD_DARK = (168, 120, 48, 255)
TEAL = (52, 160, 164, 255)
TEAL_DARK = (28, 98, 112, 255)
TEAL_LIGHT = (126, 214, 206, 255)
CLOTH = (236, 228, 204, 255)


def s(v: float) -> int:
    return int(round(v * SS))


def pts(points) -> list:
    return [(s(x), s(y)) for x, y in points]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def hull_points(x0: float, x1: float, deck: float, keel: float, n: int = 40) -> list:
    """A boat profile: flat deck, curved keel, raised prow on the right."""
    top = [(x0 - 6, deck - 8), (x0 + 10, deck)]
    top += [(x1 - 20, deck), (x1 + 14, deck - 16)]
    bottom = []
    for i in range(n + 1):
        t = i / n
        x = x1 + 14 - t * (x1 - x0 + 20)
        # Keel depth follows a sine bulge, shallower at the stern.
        depth = math.sin(math.pi * min(1.0, t * 1.05)) ** 0.7
        y = deck + (keel - deck) * depth
        bottom.append((x, y))
    return top + bottom


def shaded_polygon(img: Image.Image, poly: list, top_col, bottom_col, y0: float, y1: float) -> None:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts(poly), fill=255)
    grad = Image.new("RGBA", img.size)
    gd = ImageDraw.Draw(grad)
    for y in range(s(y0), s(y1) + 1):
        t = (y - s(y0)) / max(1, s(y1) - s(y0))
        gd.line([(0, y), (img.size[0], y)], fill=lerp(top_col, bottom_col, t))
    img.paste(grad, (0, 0), mask)


def planks(d: ImageDraw.ImageDraw, x0, x1, y0, y1, step=9, color=WOOD_DARK) -> None:
    y = y0 + step
    rng = random.Random(7)
    while y < y1:
        d.line(pts([(x0, y), (x1, y)]), fill=color, width=s(1.1))
        x = x0 + rng.uniform(10, 40)
        while x < x1:
            d.line(pts([(x, y - step + 1), (x, y - 1)]), fill=color, width=s(0.9))
            x += rng.uniform(34, 60)
        y += step


def envelope(img: Image.Image, cx, cy, rx, ry) -> None:
    d = ImageDraw.Draw(img)
    box = [s(cx - rx), s(cy - ry), s(cx + rx), s(cy + ry)]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    shade = Image.new("RGBA", img.size)
    sd = ImageDraw.Draw(shade)
    for y in range(box[1], box[3] + 1):
        t = (y - box[1]) / (box[3] - box[1])
        col = lerp(TEAL_LIGHT, TEAL, min(1, t * 1.6)) if t < 0.6 else lerp(TEAL, TEAL_DARK, (t - 0.6) / 0.4)
        sd.line([(box[0], y), (box[2], y)], fill=col)
    img.paste(shade, (0, 0), mask)
    # Fabric gores: vertical arcs, gold bands at the thirds.
    for i in range(-3, 4):
        k = i / 3.6
        band = abs(i) == 2
        arc = []
        for j in range(41):
            a = -math.pi / 2 + math.pi * j / 40
            arc.append((cx + rx * k * math.cos(a) * 0.98, cy + ry * math.sin(a) * 0.98))
        d.line(pts(arc), fill=GOLD if band else TEAL_DARK, width=s(3.2 if band else 1.1))
    # A horizontal seam and a soft highlight.
    d.arc(box, 200, 340, fill=(220, 255, 250, 150), width=s(4))
    d.line(pts([(cx - rx * 0.95, cy + 4), (cx + rx * 0.95, cy + 4)]), fill=GOLD_DARK, width=s(2.2))
    d.ellipse(box, outline=OUTLINE, width=s(2.4))
    # Nose cone and tail fins.
    fin = [(cx - rx + 8, cy - 6), (cx - rx - 26, cy - 30), (cx - rx - 20, cy - 2), (cx - rx - 26, cy + 26), (cx - rx + 8, cy + 6)]
    d.polygon(pts(fin), fill=TEAL_DARK, outline=OUTLINE)
    d.line(pts([(cx - rx - 22, cy - 2), (cx - rx + 4, cy)]), fill=GOLD, width=s(2))
    d.ellipse([s(cx + rx - 8), s(cy - 7), s(cx + rx + 6), s(cy + 7)], fill=GOLD, outline=OUTLINE, width=s(1.6))


def propeller(d: ImageDraw.ImageDraw, cx, cy, r) -> None:
    d.ellipse([s(cx - r), s(cy - r * 0.35), s(cx + r), s(cy + r * 0.35)], fill=(210, 230, 235, 90))
    for a in (0.0, math.pi):
        tip = (cx + 3 * math.cos(a), cy + r * math.sin(a + math.pi / 2))
        d.polygon(pts([(cx - 3, cy), tip, (cx + 3, cy)]), fill=WOOD_LIGHT, outline=OUTLINE)
    d.ellipse([s(cx - 4), s(cy - 4), s(cx + 4), s(cy + 4)], fill=GOLD, outline=OUTLINE, width=s(1.2))


def sky_ship() -> Image.Image:
    W, H = 340, 300
    img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    deck, keel = 196.0, 252.0
    # Rigging from the envelope down to the hull.
    for x_top, x_bot in [(110, 96), (150, 146), (196, 200), (236, 246)]:
        d.line(pts([(x_top, 128), (x_bot, deck - 4)]), fill=(70, 52, 40, 255), width=s(1.6))
    envelope(img, 172, 78, 128, 56)
    d = ImageDraw.Draw(img)
    # Pennant on top.
    d.line(pts([(172, 22), (172, 4)]), fill=OUTLINE, width=s(2))
    d.polygon(pts([(172, 4), (198, 9), (172, 14)]), fill=(226, 92, 70, 255), outline=OUTLINE)
    # Deck rail and cabin.
    d.rectangle([s(150), s(deck - 30), s(214), s(deck)], fill=WOOD, outline=OUTLINE, width=s(1.8))
    d.polygon(pts([(144, deck - 30), (182, deck - 46), (220, deck - 30)]), fill=TEAL_DARK, outline=OUTLINE)
    for wx in (162, 190):
        d.rectangle([s(wx), s(deck - 22), s(wx + 12), s(deck - 10)], fill=(255, 214, 120, 255), outline=OUTLINE, width=s(1.2))
    # Hull.
    hull = hull_points(52, 286, deck, keel)
    shaded_polygon(img, hull, WOOD_LIGHT, WOOD_DARK, deck - 16, keel)
    d = ImageDraw.Draw(img)
    clip = Image.new("RGBA", img.size)
    planks(ImageDraw.Draw(clip), 40, 300, deck, keel, step=10)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts(hull), fill=255)
    img.paste(clip, (0, 0), Image.composite(clip.getchannel("A"), Image.new("L", img.size, 0), mask))
    d = ImageDraw.Draw(img)
    d.line(pts([(48, deck + 8), (290, deck + 8)]), fill=GOLD, width=s(3))
    d.line(pts([(48, deck + 11), (290, deck + 11)]), fill=GOLD_DARK, width=s(1))
    for px in (96, 136, 176, 216, 252):
        d.ellipse([s(px - 6), s(deck + 18), s(px + 6), s(deck + 30)], fill=(250, 220, 140, 255), outline=OUTLINE, width=s(1.6))
        d.ellipse([s(px - 3), s(deck + 21), s(px + 1), s(deck + 25)], fill=(255, 250, 220, 255))
    d.polygon(pts(hull), outline=OUTLINE, width=s(2.4))
    # Railing posts.
    d.line(pts([(58, deck - 10), (282, deck - 10)]), fill=WOOD_DARK, width=s(2))
    for x in range(62, 282, 14):
        d.line(pts([(x, deck - 10), (x, deck)]), fill=WOOD_DARK, width=s(1.6))
    # Bowsprit with a little gold figurehead.
    d.line(pts([(292, deck - 14), (330, deck - 30)]), fill=WOOD_DARK, width=s(3.2))
    d.ellipse([s(322), s(deck - 38), s(336), s(deck - 24)], fill=GOLD, outline=OUTLINE, width=s(1.4))
    # Side wing (a sail-fin) amidships.
    wing = [(150, deck + 14), (100, deck + 4), (70, deck + 24), (120, deck + 40)]
    d.polygon(pts(wing), fill=(236, 232, 214, 230), outline=OUTLINE)
    d.line(pts([(150, deck + 14), (70, deck + 24)]), fill=WOOD_DARK, width=s(1.4))
    d.line(pts([(140, deck + 20), (92, deck + 34)]), fill=(190, 180, 160, 255), width=s(1))
    # Stern propeller and rudder.
    d.line(pts([(48, deck + 6), (28, deck + 6)]), fill=OUTLINE, width=s(2.4))
    propeller(d, 24, deck + 6, 22)
    d.polygon(pts([(60, deck + 18), (40, deck + 44), (66, deck + 40)]), fill=WOOD_DARK, outline=OUTLINE)
    # Rope ladder down to the ground (the boarding spot).
    for x in (254, 266):
        d.line(pts([(x, keel - 18), (x + 6, 296)]), fill=(120, 86, 56, 255), width=s(1.6))
    for y in range(int(keel) - 4, 296, 8):
        t = (y - keel + 18) / (296 - keel + 18)
        d.line(pts([(254 + 6 * t, y), (266 + 6 * t, y)]), fill=(150, 110, 70, 255), width=s(1.6))
    return finish(img)


def wreck() -> Image.Image:
    W, H = 340, 220
    img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Deflated envelope draped on the sand (behind the hull).
    cloth = [(14, 168), (22, 140), (34, 118), (52, 108), (70, 116), (88, 102), (110, 108), (128, 100), (146, 116), (150, 140), (138, 166), (116, 176), (96, 170), (74, 180), (50, 174), (30, 180)]
    shaded_polygon(img, cloth, TEAL, TEAL_DARK, 88, 178)
    d = ImageDraw.Draw(img)
    for k in range(5):
        x = 34 + k * 22
        d.line(pts([(x, 100 + k * 2), (x + 12, 170)]), fill=TEAL_DARK, width=s(2))
    d.line(pts([(40, 106), (140, 118)]), fill=GOLD_DARK, width=s(2.6))
    d.polygon(pts(cloth), outline=OUTLINE, width=s(2))
    # Tilted hull, half buried.
    deck, keel = 120.0, 172.0
    hull = hull_points(100, 300, deck, keel)
    pivot = (200, 146)
    ang = math.radians(-7)
    rot = [(pivot[0] + (x - pivot[0]) * math.cos(ang) - (y - pivot[1]) * math.sin(ang),
            pivot[1] + (x - pivot[0]) * math.sin(ang) + (y - pivot[1]) * math.cos(ang)) for x, y in hull]
    shaded_polygon(img, rot, (150, 104, 70, 255), (74, 46, 30, 255), 96, 180)
    d = ImageDraw.Draw(img)
    clip = Image.new("RGBA", img.size)
    planks(ImageDraw.Draw(clip), 80, 320, 100, 180, step=10, color=(60, 38, 26, 255))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts(rot), fill=255)
    img.paste(clip, (0, 0), Image.composite(clip.getchannel("A"), Image.new("L", img.size, 0), mask))
    d = ImageDraw.Draw(img)
    # Holes in the planking.
    for hx, hy, r in [(170, 150, 11), (236, 138, 8), (206, 158, 6)]:
        d.polygon(pts([(hx - r, hy), (hx - r * 0.3, hy - r * 0.9), (hx + r, hy - r * 0.2), (hx + r * 0.4, hy + r * 0.8)]), fill=(28, 18, 14, 255))
    d.line(pts([(104, 118), (296, 94)]), fill=GOLD_DARK, width=s(2.6))
    d.polygon(pts(rot), outline=OUTLINE, width=s(2.4))
    # Broken mast with a torn sail.
    d.line(pts([(204, 104), (192, 30)]), fill=WOOD_DARK, width=s(5))
    d.polygon(pts([(186, 30), (190, 24), (198, 31), (194, 36)]), fill=WOOD_LIGHT, outline=OUTLINE)
    sail = [(196, 44), (238, 52), (232, 70), (244, 80), (214, 86), (199, 80)]
    d.polygon(pts(sail), fill=CLOTH, outline=OUTLINE)
    d.line(pts([(204, 54), (226, 74)]), fill=(200, 188, 160, 255), width=s(1.2))
    # Sand drift over the keel and scattered planks.
    # A soft contact shadow where the hull sinks into the sand.
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([s(96), s(160), s(316), s(190)], fill=(60, 40, 20, 90))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(s(4))))
    d = ImageDraw.Draw(img)
    for x, y, a in [(70, 186, 0.2), (300, 182, -0.3), (264, 190, 0.1)]:
        dx, dy = 18 * math.cos(a), 18 * math.sin(a)
        d.line(pts([(x - dx, y - dy), (x + dx, y + dy)]), fill=WOOD, width=s(4))
        d.line(pts([(x - dx, y - dy - 2), (x + dx, y + dy - 2)]), fill=WOOD_LIGHT, width=s(1))
    return finish(img)


def finish(img: Image.Image) -> Image.Image:
    rng = random.Random(3)
    grain = Image.new("L", (img.width // 8, img.height // 8))
    grain.putdata([rng.randint(108, 148) for _ in range(grain.width * grain.height)])
    grain = grain.resize(img.size, Image.BILINEAR)
    alpha = img.getchannel("A")
    from PIL import ImageChops
    rgb = img.convert("RGB")
    rgb = ImageChops.overlay(rgb, Image.merge("RGB", (grain, grain, grain)))
    img = Image.merge("RGBA", (*rgb.split(), alpha))
    small = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    return small.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    sky_ship().save(OUT / "sky_ship.png")
    wreck().save(OUT / "sky_ship_wreck.png")
    print("ship sprites written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
