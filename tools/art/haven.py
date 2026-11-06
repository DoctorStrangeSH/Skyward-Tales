"""Тихая Гавань (Quiet Haven): the peaceful island town.

Fountain, flower beds, benches, a flower arch, a windmill, the ancient sky
anchor, roof colour variants, lore steles and the small quest pickups.
Same warm pack palette as village.py.

Run: python3 tools/art/haven.py   (writes assets/world/village_*.png,
assets/props/*.png and their origins into assets/art_manifest.json)
"""
from __future__ import annotations

import json
import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from pixel import Canvas, hex_color  # noqa: E402
import village  # noqa: E402
from village import GLASS, GREEN, MOSS, OUTLINE, PLASTER, ROOF, SLATE, STONE, TIMBER, WINE, _roof  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
WATER = [hex_color(c) for c in ("#14496a", "#1b6f8a", "#2f9aa6", "#6fd0c6", "#d6f6ea")]
PETALS = [
    [hex_color("#f28fb1"), hex_color("#ffc4d8")],
    [hex_color("#f6d55c"), hex_color("#fff2a8")],
    [hex_color("#93bcff"), hex_color("#d6e6ff")],
    [hex_color("#f4f1de"), hex_color("#ffffff")],
    [hex_color("#e86a5a"), hex_color("#ffb0a0")],
    [hex_color("#c9a2ff"), hex_color("#eedcff")],
]
RUNE = hex_color("#8ff7ef")
SKY_ROOF = [hex_color(c) for c in ("#1f3a3a", "#285050", "#2f6a62", "#3d8a78", "#56a890", "#86ccb0")]


def _ellipse_fill(c: Canvas, cx: float, cy: float, rx: float, ry: float, color) -> None:
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                c.put(x, y, color)


def fountain() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(64, 52)
    for x in range(4, 60):
        c.blend(x, 48, (20, 14, 10, 70))
    # Outer stone rim and basin water.
    _ellipse_fill(c, 32, 38, 28, 11, STONE[3])
    _ellipse_fill(c, 32, 37, 28, 10, STONE[4])
    _ellipse_fill(c, 32, 36, 24, 7.5, WATER[1])
    _ellipse_fill(c, 32, 35, 22, 6, WATER[2])
    for x in range(12, 52, 6):
        c.put(x, 35 + (x // 6) % 2, WATER[3])
    # Rim blocks.
    for i in range(0, 360, 30):
        a = math.radians(i)
        x, y = 32 + math.cos(a) * 27, 38 + math.sin(a) * 10.5
        c.put(int(x), int(y), STONE[2])
    # Pillar and the upper bowl.
    c.rect(29, 16, 6, 20, STONE[3])
    c.vline(29, 16, 35, STONE[2])
    c.vline(34, 16, 35, STONE[5])
    _ellipse_fill(c, 32, 17, 11, 4, STONE[4])
    _ellipse_fill(c, 32, 16, 9, 2.5, WATER[2])
    # Spray and falling water.
    c.rect(31, 4, 2, 12, WATER[3])
    c.put(31, 3, WATER[4])
    c.put(32, 2, WATER[4])
    for side in (-1, 1):
        for k in range(10):
            x = 32 + side * (9 + k // 2)
            y = 18 + k
            c.put(x, y, WATER[3] if k % 3 else WATER[4])
        for k in range(4):
            c.put(32 + side * (3 + k * 2), 4 + k * 3, WATER[4])
    # Rune ring on the pillar.
    c.put(31, 24, RUNE)
    c.put(32, 27, RUNE)
    c.outline(OUTLINE)
    return c, (32, 48)


def flowerbed(seed: int) -> tuple[Canvas, tuple[int, int]]:
    rng = random.Random(seed)
    c = Canvas(34, 18)
    c.rect(1, 6, 32, 10, TIMBER[2])
    c.rect(2, 7, 30, 8, village.SOIL[1])
    c.hline(1, 32, 6, TIMBER[4])
    for _ in range(14):
        x, y = rng.randint(3, 30), rng.randint(3, 12)
        c.put(x, y + 1, GREEN[3])
        c.put(x, y + 2, GREEN[2])
    picks = rng.sample(PETALS, 3)
    for _ in range(18):
        x, y = rng.randint(3, 30), rng.randint(2, 11)
        petal = picks[rng.randrange(3)]
        c.put(x, y, petal[0])
        c.put(x + 1, y, petal[0])
        c.put(x, y - 1, petal[1])
    c.outline(OUTLINE)
    return c, (17, 16)


def bench() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(30, 18)
    c.rect(3, 3, 24, 3, TIMBER[3])
    c.hline(3, 26, 3, TIMBER[4])
    c.rect(3, 9, 24, 3, TIMBER[3])
    c.hline(3, 26, 9, TIMBER[4])
    for x in (5, 23):
        c.rect(x, 6, 2, 10, TIMBER[1])
    c.outline(OUTLINE)
    return c, (15, 16)


def arch() -> tuple[Canvas, tuple[int, int]]:
    rng = random.Random(7)
    c = Canvas(56, 54)
    for x in (6, 46):
        c.rect(x, 14, 4, 38, TIMBER[2])
        c.vline(x, 14, 51, TIMBER[1])
    for k in range(40):
        a = math.pi * k / 39
        x, y = 28 - math.cos(a) * 20, 18 - math.sin(a) * 14
        c.rect(int(x) - 1, int(y), 4, 3, TIMBER[3])
    # Vines and flowers.
    for k in range(60):
        a = math.pi * rng.random()
        x, y = 28 - math.cos(a) * 20 + rng.randint(-2, 2), 18 - math.sin(a) * 14 + rng.randint(-2, 2)
        c.put(int(x), int(y), GREEN[rng.randint(2, 4)])
    for side in (8, 48):
        for y in range(16, 50, 2):
            c.put(side + rng.randint(-2, 2), y, GREEN[rng.randint(2, 4)])
    for k in range(22):
        a = math.pi * rng.random()
        x, y = 28 - math.cos(a) * 20, 18 - math.sin(a) * 14
        petal = PETALS[k % 3]
        c.put(int(x), int(y) - 1, petal[0])
        c.put(int(x) + 1, int(y) - 1, petal[1])
    c.outline(OUTLINE)
    return c, (28, 51)


def windmill() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(84, 112)
    for x in range(22, 62):
        c.blend(x, 108, (20, 14, 10, 70))
    # Tapered tower.
    for y in range(40, 106):
        half = 12 + (y - 40) * 6 // 66
        c.hline(42 - half, 42 + half, y, PLASTER[2])
        c.put(42 - half, y, PLASTER[1])
        c.put(42 + half, y, PLASTER[0])
    for y in range(46, 104, 9):
        half = 12 + (y - 40) * 6 // 66
        c.hline(42 - half, 42 + half, y, PLASTER[1])
    c.rect(24, 100, 37, 7, STONE[2])
    c.hline(24, 60, 100, STONE[4])
    village._door(c, 37, 88)
    village._window(c, 38, 58, 7, 7)
    # Cap roof.
    _roof(c, 26, 30, 33, 12, WINE, 11)
    c.hline(30, 54, 29, WINE[4])
    c.hline(34, 50, 28, WINE[5])
    # Sails: four blades around the hub.
    hub = (42, 40)
    for angle in (20, 110, 200, 290):
        a = math.radians(angle)
        for r in range(4, 38):
            x = hub[0] + math.cos(a) * r
            y = hub[1] + math.sin(a) * r
            c.put(int(x), int(y), TIMBER[1])
            if r > 9:
                for w in range(1, 7):
                    px = x + math.cos(a + math.pi / 2) * w
                    py = y + math.sin(a + math.pi / 2) * w
                    c.put(int(round(px)), int(round(py)), PLASTER[3] if (r + w) % 5 else TIMBER[3])
    c.rect(40, 38, 5, 5, TIMBER[0])
    c.put(42, 40, hex_color("#f4b41b"))
    c.outline(OUTLINE)
    return c, (42, 107)


def sky_anchor() -> tuple[Canvas, tuple[int, int]]:
    """The Keepers' ancient anchor: a carved stone with a chain into the sky."""
    c = Canvas(56, 128)
    for x in range(8, 48):
        c.blend(x, 124, (20, 14, 10, 80))
    # Plinth.
    c.rect(6, 108, 44, 16, STONE[2])
    c.rect(8, 106, 40, 4, STONE[4])
    c.hline(6, 49, 123, STONE[1])
    for x in range(10, 48, 8):
        c.put(x, 114, RUNE)
        c.put(x + 1, 115, RUNE)
    # Anchor body.
    c.rect(24, 56, 8, 52, STONE[3])
    c.vline(24, 56, 107, STONE[2])
    c.vline(31, 56, 107, STONE[5])
    for k in range(26):
        a = math.pi * k / 25
        x, y = 28 - math.cos(a) * 20, 92 + math.sin(a) * 12
        c.rect(int(x) - 1, int(y) - 1, 4, 4, STONE[3])
    for side in (-1, 1):
        x = 28 + side * 20
        c.rect(x - 2, 84, 4, 8, STONE[4])
        c.put(x, 82, STONE[5])
    c.rect(16, 60, 24, 5, STONE[4])
    _ellipse_fill(c, 28, 52, 7, 7, STONE[3])
    _ellipse_fill(c, 28, 52, 3.5, 3.5, (0, 0, 0, 0))
    for y in range(68, 104, 6):
        c.put(27, y, RUNE)
        c.put(28, y + 1, RUNE)
    # The chain rising to the clouds, fading out.
    for i, y in enumerate(range(44, -1, -5)):
        alpha = max(60, 255 - i * 18)
        col = hex_color("#9aa2b0", alpha)
        hi = hex_color("#d8dce4", alpha)
        if i % 2 == 0:
            for dy in range(5):
                c.put(26, y - dy, col)
                c.put(30, y - dy, col)
            c.put(27, y - 4, hi)
        else:
            for dy in range(5):
                c.put(28, y - dy, col)
            c.put(28, y - 2, hi)
    c.outline(OUTLINE)
    return c, (28, 123)


def market_awning(seed: int, pal) -> tuple[Canvas, tuple[int, int]]:
    """A striped market stall with baskets of fruit and bread."""
    rng = random.Random(seed)
    c = Canvas(52, 44)
    for x in (4, 46):
        c.rect(x, 12, 3, 28, TIMBER[1])
    for x in range(2, 50):
        for y in range(4, 14):
            stripe = (x // 6) % 2
            c.put(x, y, pal[4] if stripe else PLASTER[3])
        c.put(x, 14 + (x % 6 < 3), pal[2] if (x // 6) % 2 else PLASTER[2])
    c.rect(4, 28, 44, 10, TIMBER[3])
    c.hline(4, 47, 28, TIMBER[4])
    for k in range(5):
        x = 7 + k * 8
        c.rect(x, 23, 7, 5, TIMBER[2])
        fruit = PETALS[rng.randrange(len(PETALS))][0] if k != 2 else hex_color("#d89850")
        for j in range(6):
            c.put(x + rng.randint(0, 6), 22 + rng.randint(0, 2), fruit)
    c.outline(OUTLINE)
    return c, (26, 40)


def stele() -> Canvas:
    """A small rune stone with a story carved in it (lore pickup)."""
    c = Canvas(18, 26)
    for x in range(3, 15):
        c.blend(x, 24, (20, 14, 10, 80))
    c.rect(4, 6, 10, 18, STONE[3])
    c.rect(5, 4, 8, 3, STONE[3])
    c.vline(4, 6, 23, STONE[2])
    c.vline(13, 6, 23, STONE[4])
    for y in (9, 12, 15, 18):
        c.hline(6, 11, y, RUNE if y != 15 else STONE[1])
    c.outline(OUTLINE)
    return c


def letter() -> Canvas:
    c = Canvas(16, 14)
    c.rect(2, 3, 12, 9, PLASTER[3])
    c.line(2, 3, 8, 8, PLASTER[0])
    c.line(13, 3, 8, 8, PLASTER[0])
    c.put(8, 8, hex_color("#c8352e"))
    c.put(7, 8, hex_color("#e05a4a"))
    c.outline(OUTLINE)
    return c


def flour_sack() -> Canvas:
    c = Canvas(16, 16)
    _ellipse_fill(c, 8, 10, 5.5, 5, PLASTER[2])
    _ellipse_fill(c, 7, 9, 3, 3, PLASTER[3])
    c.rect(6, 3, 5, 3, PLASTER[1])
    c.hline(5, 11, 5, TIMBER[2])
    c.put(8, 10, TIMBER[3])
    c.put(9, 11, TIMBER[3])
    c.outline(OUTLINE)
    return c


def sky_seed() -> Canvas:
    c = Canvas(16, 16)
    _ellipse_fill(c, 8, 9, 3.5, 4.5, hex_color("#e8c070"))
    _ellipse_fill(c, 7, 8, 1.5, 2, hex_color("#fff2b0"))
    for k in range(5):
        c.put(8 + (k - 2) * 2, 3 - abs(k - 2), hex_color("#ffffff"))
        c.put(8 + (k - 2), 4, hex_color("#e0f4ff"))
    c.outline(OUTLINE)
    return c


def song_scroll() -> Canvas:
    c = Canvas(16, 16)
    c.rect(3, 4, 10, 8, PLASTER[3])
    c.vline(3, 3, 12, TIMBER[3])
    c.vline(12, 3, 12, TIMBER[3])
    for x, y in ((5, 6), (8, 7), (10, 6), (6, 9), (9, 10)):
        c.put(x, y, TIMBER[0])
        c.put(x, y - 1, TIMBER[0])
    c.outline(OUTLINE)
    return c


def kitten() -> Canvas:
    fur = [hex_color(c) for c in ("#6a4a3a", "#c8823a", "#f0b060", "#ffe0b0")]
    c = Canvas(18, 16)
    _ellipse_fill(c, 9, 11, 5, 3.5, fur[1])
    _ellipse_fill(c, 9, 10, 3, 2, fur[2])
    _ellipse_fill(c, 13, 7, 3.5, 3, fur[1])
    c.put(11, 4, fur[1])
    c.put(15, 4, fur[1])
    c.put(12, 7, hex_color("#1a1a1a"))
    c.put(14, 7, hex_color("#1a1a1a"))
    c.put(13, 8, hex_color("#f28fb1"))
    for k in range(5):
        c.put(4 - k // 2, 10 - k, fur[1])
    c.outline(OUTLINE)
    return c


def build(root: pathlib.Path = ROOT) -> None:
    world = {
        "village_fountain": fountain(),
        "village_flowers_a": flowerbed(1),
        "village_flowers_b": flowerbed(2),
        "village_flowers_c": flowerbed(3),
        "village_bench": bench(),
        "village_arch": arch(),
        "village_windmill": windmill(),
        "village_anchor": sky_anchor(),
        "village_market_red": market_awning(4, WINE),
        "village_market_green": market_awning(5, MOSS),
        "village_house_wine": village.house(68, roof_pal=WINE, seed=12),
        "village_house_moss": village.house(80, roof_pal=SKY_ROOF, windows=2, seed=13),
        "village_house_blue": village.house(60, roof_pal=SLATE, seed=14, chimney=False),
        "village_house_long": village.house(104, roof_pal=ROOF, windows=2, seed=15),
    }
    props = {"lore_stone": stele(), "lost_letter": letter(), "flour_sack": flour_sack(),
             "sky_seed": sky_seed(), "song_scroll": song_scroll(), "lost_kitten": kitten()}
    manifest_path = root / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    for name, (canvas, origin) in world.items():
        rel = f"world/{name}.png"
        canvas.save(root / "assets" / rel)
        art[rel] = {"size": [canvas.w, canvas.h], "origin": list(origin)}
    for name, canvas in props.items():
        rel = f"props/{name}.png"
        canvas.save(root / "assets" / rel)
        art[rel] = {"size": [canvas.w, canvas.h], "origin": [canvas.w // 2, canvas.h - 2]}
        # The same picture serves as the inventory icon.
        icon = Canvas(16, 16)
        scale_src = canvas
        ox, oy = (16 - min(16, scale_src.w)) // 2, (16 - min(16, scale_src.h)) // 2
        for y in range(min(16, scale_src.h)):
            for x in range(min(16, scale_src.w)):
                px = scale_src.get(x + max(0, (scale_src.w - 16) // 2), y + max(0, scale_src.h - 16))
                if px[3]:
                    icon.put(x + ox, y + oy, px)
        icon.save(root / "assets" / "icons" / f"{name}.png")
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("  haven: " + ", ".join(list(world) + list(props)))


if __name__ == "__main__":
    build()
