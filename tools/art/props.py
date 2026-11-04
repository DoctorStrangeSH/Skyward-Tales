"""Large scenery props drawn in 3/4 top-down view (top faces lighter, fronts darker)."""
from __future__ import annotations

import math

import random

from pixel import Canvas


def _block(c: Canvas, x: int, y: int, w: int, h: int, stone, top: int = 0) -> None:
    """A masonry block: optional lit top face, front face with left highlight."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if yy < y + top:
                color = stone[4]
            elif xx == x:
                color = stone[3]
            elif xx == x + w - 1 or yy == y + h - 1:
                color = stone[1]
            else:
                color = stone[2]
            c.put(xx, yy, color)
    if top:
        c.hline(x, x + w - 1, y, stone[5])


def _brick_face(c: Canvas, x0: int, y0: int, x1: int, y1: int, stone, rng: random.Random) -> None:
    row_h = 6
    for row, y in enumerate(range(y0, y1, row_h)):
        offset = (row % 2) * 6
        x = x0 - offset
        while x < x1:
            bw = rng.choice((10, 12, 12, 14))
            bx0, bx1 = max(x, x0), min(x + bw, x1)
            if bx1 - bx0 >= 2:
                _block(c, bx0, y, bx1 - bx0, min(row_h, y1 - y), stone)
            x += bw
    # Cracks.
    for _ in range((x1 - x0) // 14):
        cx, cy = rng.randrange(x0 + 2, x1 - 2), rng.randrange(y0 + 2, y1 - 3)
        for i in range(rng.randint(3, 6)):
            c.put(cx + (i % 2), cy + i, stone[0])


def _moss(c: Canvas, x0: int, x1: int, y: int, moss, rng: random.Random, hang: int = 4) -> None:
    for x in range(x0, x1):
        if rng.random() < 0.7:
            c.put(x, y, moss[3] if rng.random() < 0.4 else moss[2])
            length = rng.randint(0, hang) if rng.random() < 0.35 else 0
            for i in range(1, length + 1):
                c.put(x, y + i, moss[1] if i == length else moss[2])


def ruins(pal, seed: int = 3) -> tuple[Canvas, tuple[int, int]]:
    rng = random.Random(seed)
    stone, moss, leaf = pal["stone"], pal["moss"], pal["leaf"]
    c = Canvas(108, 110)
    origin = (54, 104)
    # Ground shadow.
    for y in range(98, 108):
        for x in range(4, 106):
            if ((x - 56) / 52) ** 2 + ((y - 103) / 5) ** 2 <= 1:
                c.blend(x, y, pal["shadow"])
    # Top surface: broken flagstones overgrown with grass.
    for y in range(46, 77):
        for x in range(8, 100):
            jitter = (x * 13 + y * 7) % 5
            if y < 50 and (x * 7 + 3) % 17 < 4:
                continue  # broken back edge
            tile = ((x // 9) + (y // 7)) % 2
            color = stone[4] if tile else stone[3]
            if (x % 9 == 0) or (y % 7 == 0):
                color = stone[2]
            if jitter == 0 and rng.random() < 0.25:
                color = moss[2]
            c.put(x, y, color)
    for _ in range(26):
        x, y = rng.randrange(10, 98), rng.randrange(48, 75)
        for dx in range(rng.randint(2, 6)):
            c.put(x + dx, y, moss[3] if dx % 2 else moss[2])
            c.put(x + dx, y + 1, moss[1])
    # Front face: brick wall with a sealed arch.
    _brick_face(c, 8, 77, 100, 103, stone, rng)
    c.hline(8, 99, 77, stone[5])
    for y in range(83, 103):
        for x in range(46, 62):
            dy = 83 + 5 - y
            if y < 88 and (x - 54) ** 2 + (dy * 1.6) ** 2 > 64:
                continue
            c.put(x, y, stone[0] if x < 58 else stone[1])
    for x in range(45, 63):
        c.put(x, 82 if 49 < x < 59 else 84, stone[4])
    _moss(c, 8, 100, 78, moss, rng, hang=6)
    # Pillars rising from the back of the ruin; the right one is broken.
    for px, top in ((22, 8), (66, 26)):
        _block(c, px, top, 13, 58 - top + 2, stone, top=3)
        for y in range(top + 6, 58, 6):
            c.hline(px + 1, px + 11, y, stone[1])
        _block(c, px - 2, 56, 17, 6, stone, top=2)
        if px == 22:
            _block(c, px - 3, top - 4, 19, 6, stone, top=2)
        else:
            for x in range(px, px + 13):
                if (x * 5) % 7 < 3:
                    c.put(x, top, (0, 0, 0, 0))
                    c.put(x, top + 1, stone[4])
        _moss(c, px, px + 13, top + 2, moss, rng, hang=8)
    # Ivy climbing the left pillar.
    for y in range(14, 58):
        x = 23 + int(2 * ((y // 5) % 2))
        if rng.random() < 0.8:
            c.put(x, y, leaf[3])
            c.put(x + 1, y, leaf[4] if y % 3 else leaf[5])
    # Rubble at the base.
    for bx, by, bw in ((3, 98, 7), (96, 96, 8), (70, 99, 6), (30, 100, 5)):
        _block(c, bx, by, bw, 5, stone, top=2)
    c.outline(pal["outline"])
    return c, origin


def _menhir(c: Canvas, x: int, base: int, w: int, h: int, pal, rng: random.Random) -> None:
    stone, glow = pal["stone"], pal["glow"]
    top = base - h
    for y in range(top, base):
        t = (y - top) / h
        inset = 3 if t < 0.08 else (1 if t < 0.16 else 0)
        for xx in range(x + inset, x + w - inset):
            rel = (xx - x) / w
            color = stone[4] if rel < 0.25 else (stone[3] if rel < 0.65 else stone[2])
            if y < top + 3:
                color = stone[5] if rel < 0.6 else stone[4]
            c.put(xx, y, color)
    # Carved glowing runes with a faint halo.
    for i, ry in enumerate(range(top + 9, base - 8, 7)):
        cx = x + w // 2
        pattern = [(0, 0), (0, 1), (0, 2), (-1, 1 + i % 2), (1, i % 3)]
        for dx, dy in pattern:
            for hx in (-1, 0, 1):
                for hy in (-1, 0, 1):
                    c.blend(cx + dx + hx, ry + dy + hy, (*glow[0][:3], 50))
        for dx, dy in pattern:
            c.put(cx + dx, ry + dy, glow[2] if dy == 0 else glow[1])
    for xx in range(x, x + w):
        if rng.random() < 0.7:
            c.put(xx, base - 1, pal["moss"][2])
            if rng.random() < 0.5:
                c.put(xx, base - 2, pal["moss"][3])


def standing_stones(pal, seed: int = 5) -> tuple[Canvas, tuple[int, int]]:
    rng = random.Random(seed)
    stone = pal["stone"]
    c = Canvas(120, 84)
    origin = (60, 78)  # world [985, 612]
    for y in range(70, 84):
        for x in range(0, 120):
            if ((x - 62) / 58) ** 2 + ((y - 76) / 6) ** 2 <= 1:
                c.blend(x, y, pal["shadow"])
    # Menhirs centred on the collision blockers at world x 946 and 1024.
    _menhir(c, 60 - 39 - 8, 74, 16, 50, pal, rng)
    _menhir(c, 60 + 39 - 8, 74, 16, 44, pal, rng)
    # Fallen lintel and a low altar between them.
    _block(c, 36, 64, 48, 9, stone, top=3)
    for x in range(38, 82, 5):
        c.put(x, 68, stone[1])
    _block(c, 52, 56, 16, 9, stone, top=3)
    glow = pal["glow"]
    for dx in range(-2, 3):
        c.put(60 + dx, 57, glow[1])
    c.put(60, 56, glow[2])
    c.outline(pal["outline"])
    return c, origin


# --- small interactive props (origin = point that sits on the node position) ----

from pixel import hex_color, ramp  # noqa: E402

OUTLINE = hex_color("#241a30")
WOOD = ramp("#d39a5e", "#a8703f", "#7a4c2e", "#523224")
GOLD = ramp("#fff2a8", "#ffd45c", "#d99a2e", "#9a5a22")
IRON = ramp("#d6dcdc", "#a9b3bd", "#7f899a", "#4f5866")


def _shadow(c: Canvas, cx: float, cy: float, rx: float, ry: float) -> None:
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                c.blend(x, y, (16, 24, 32, 80))


def _finish(c: Canvas) -> None:
    shadow = c.px[:, :, 3] < 255
    keep = c.px.copy()
    solid = Canvas(c.w, c.h)
    solid.px[~shadow] = c.px[~shadow]
    solid.outline(OUTLINE)
    edge = (solid.px[:, :, 3] == 255) & shadow
    keep[edge] = OUTLINE
    c.px = keep


def chest(opened: bool) -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(24, 24)
    _shadow(c, 12, 20, 10, 2.5)
    # Body.
    for y in range(11, 20):
        for x in range(3, 21):
            color = WOOD[1] if x > 3 else WOOD[0]
            if x == 20 or y == 19:
                color = WOOD[2]
            if y in (14, 15) and (x + y) % 6 == 0:
                color = WOOD[2]
            c.put(x, y, color)
    for x in (5, 18):
        c.vline(x, 11, 19, GOLD[2])
    if opened:
        # Lid tilted back, dark interior with a glint of coins.
        c.rect(3, 4, 18, 5, WOOD[2])
        c.hline(3, 20, 4, WOOD[1])
        c.rect(4, 9, 16, 3, hex_color("#2a1a22"))
        for x in (7, 9, 12, 15):
            c.put(x, 10, GOLD[1])
        c.put(10, 9, GOLD[0])
    else:
        for y in range(6, 11):
            for x in range(3, 21):
                c.put(x, y, WOOD[0] if y < 8 else WOOD[1])
        c.hline(4, 19, 6, GOLD[0])
        for x in (5, 18):
            c.vline(x, 6, 10, GOLD[1])
        c.rect(10, 9, 4, 4, GOLD[1])
        c.put(10, 9, GOLD[0])
        c.put(11, 11, hex_color("#3a2420"))
    _finish(c)
    return c, (12, 19)


def herb(kind: str) -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(20, 22)
    _shadow(c, 10, 19, 6, 1.8)
    glow = {"moonleaf": ramp("#f4fff0", "#c8f0d8", "#7fcfae", "#3f8f7a"),
            "spirit_blossom": ramp("#f4ffff", "#9cfff0", "#3fd6d0", "#1f8a8a"),
            "memory_crystal": ramp("#fffbe0", "#fff2a8", "#ffd45c", "#c88a2a"),
            "wind_rune": ramp("#ffffff", "#c8f4ff", "#7ad0f0", "#3a7ab0"),
            "echo_crystal": ramp("#f6f0ff", "#d0b8ff", "#9a7aff", "#5a3ac0")}[kind]
    stem = ramp("#8fd862", "#4fa04e", "#2a6a44")
    if kind not in ("echo_crystal", "memory_crystal", "wind_rune"):
        for y in range(9, 19):
            c.put(10, y, stem[1] if y % 3 else stem[2])
    # Halo.
    for y in range(0, 16):
        for x in range(0, 20):
            d = ((x - 10) / 9) ** 2 + ((y - 7) / 7) ** 2
            if d <= 1:
                c.blend(x, y, glow[2][:3] + (int(45 * (1 - d)),))
    if kind == "wind_rune":
        # Weathered standing stone with a glowing wind spiral.
        stone = ramp("#f0d8c0", "#ccaa96", "#a6827a", "#7e5e64")
        for y in range(3, 19):
            half = 4 if y > 5 else 4 - (6 - y)
            for x in range(10 - half, 10 + half + 1):
                c.put(x, y, stone[0] if x < 8 else (stone[1] if x < 12 else stone[2]))
        for k in range(14):
            ang = k * 0.55
            r = 0.4 + k * 0.22
            c.put(round(10 + math.cos(ang) * r), round(10 + math.sin(ang) * r), glow[1] if k < 10 else glow[0])
        c.put(10, 10, glow[0])
    elif kind in ("echo_crystal", "memory_crystal"):
        # Three faceted shards growing from a stone.
        for sx, top, w in ((10, 2, 2), (6, 8, 1), (14, 7, 1)):
            for y in range(top, 18):
                p = (y - top) / (18 - top)
                half = max(0, round(w * min(1, p * 2.5 + 0.3)))
                for x in range(sx - half, sx + half + 1):
                    c.put(x, y, glow[0] if x < sx else (glow[1] if x == sx else glow[2]))
        for x in range(4, 17):
            c.put(x, 18, ramp("#4a4664", "#34304a")[0 if x < 9 else 1])
    elif kind == "moonleaf":
        for side in (-1, 1):
            for i in range(6):
                for w in range(3 - abs(i - 3) // 2):
                    c.put(10 + side * (1 + i), 12 - i // 2 - w, glow[1] if w == 0 else glow[2])
        for i in range(5):
            c.put(10, 8 - i, glow[0] if i > 2 else glow[1])
            c.put(9, 7 - i, glow[2])
    else:
        for dx, dy in ((0, -3), (3, 0), (0, 3), (-3, 0), (2, -2), (-2, 2), (2, 2), (-2, -2)):
            c.ellipse(10 + dx, 7 + dy, 2, 2, glow[2] if dy > 0 else glow[1])
        c.ellipse(10, 7, 1.6, 1.6, glow[0])
        c.put(10, 7, hex_color("#ffffff"))
        for side in (-1, 1):
            c.put(10 + side, 15, stem[0])
            c.put(10 + side * 2, 14, stem[0])
    _finish(c)
    return c, (10, 18)


def ore_node() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(26, 22)
    _shadow(c, 13, 19, 11, 2.5)
    stone = ramp("#a9b3bd", "#7f899a", "#5a6074", "#3c3d52")
    for cx, cy, rx, ry in ((10, 13, 7, 6), (16, 12, 6, 7), (13, 16, 9, 4)):
        for y in range(c.h):
            for x in range(c.w):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d <= 1:
                    lit = (cx - x) * 0.6 + (cy - y) * 0.8
                    c.put(x, y, stone[0] if lit > 3 else (stone[1] if lit > -2 else stone[2]))
    ore = ramp("#ffe0a8", "#e8a05a", "#b8643a", "#7a3a2a")
    for x, y in ((9, 10), (15, 8), (17, 14), (11, 15), (14, 11)):
        c.put(x, y, ore[1])
        c.put(x + 1, y, ore[2])
        c.put(x, y - 1, ore[0])
    _finish(c)
    return c, (13, 18)


def crate() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(22, 22)
    _shadow(c, 11, 19, 9, 2.2)
    for y in range(4, 19):
        for x in range(3, 19):
            top = y < 8
            color = WOOD[0] if top else WOOD[1]
            if x in (3, 18) or y in (8, 18):
                color = WOOD[2]
            if not top and (x == y + 2 or x == 22 - y):
                color = WOOD[2]
            c.put(x, y, color)
    c.hline(4, 17, 4, WOOD[0])
    for x in (5, 16):
        c.put(x, 10, IRON[1])
        c.put(x, 16, IRON[1])
    c.rect(8, 5, 6, 2, hex_color("#e8f0c8"))
    _finish(c)
    return c, (11, 18)


def scroll() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(18, 16)
    _shadow(c, 9, 13, 7, 1.8)
    paper = ramp("#fff8e6", "#eadbb8", "#c9b48e")
    for y in range(6, 12):
        for x in range(4, 15):
            c.put(x, y, paper[0] if y < 8 else paper[1])
    c.vline(3, 5, 12, WOOD[1])
    c.vline(15, 5, 12, WOOD[1])
    for x in range(6, 13, 2):
        c.put(x, 8, hex_color("#7a6a58"))
        c.put(x + 1, 10, hex_color("#7a6a58"))
    c.put(9, 9, hex_color("#e8452e"))
    _finish(c)
    return c, (9, 12)


def potion(liquid: str) -> tuple[Canvas, tuple[int, int]]:
    colors = {"red": ramp("#ffb0b8", "#f05a6a", "#b8303f", "#7a1f33"),
              "blue": ramp("#c6ecff", "#5aaaf0", "#2f6ec0", "#1f4080")}[liquid]
    c = Canvas(14, 16)
    _shadow(c, 7, 14, 5, 1.5)
    c.ellipse(7, 9.5, 4.5, 4.2, colors[1])
    for y in range(6, 14):
        for x in range(2, 12):
            if c.alpha(x, y) and (x > 8 or y > 11):
                c.put(x, y, colors[2])
    c.put(5, 8, colors[0])
    c.put(5, 9, hex_color("#ffffff"))
    c.rect(6, 3, 3, 3, hex_color("#d6e6f0"))
    c.rect(6, 2, 3, 1, WOOD[1])
    _finish(c)
    return c, (7, 13)


def pelt() -> tuple[Canvas, tuple[int, int]]:
    fur = ramp("#c9d4e6", "#8c9ab8", "#5d6a8c", "#3b4463")
    c = Canvas(20, 14)
    _shadow(c, 10, 11, 8, 1.8)
    c.ellipse(10, 7.5, 7.5, 3.6, fur[1])
    for x in range(3, 18):
        c.put(x, 6, fur[0] if x % 3 else fur[1])
        c.put(x, 9, fur[2])
    c.hline(5, 15, 7, hex_color("#c99a5d"))
    _finish(c)
    return c, (10, 10)


def treasure(kind: str) -> tuple[Canvas, tuple[int, int]]:
    """Generic glowing pouch for equipment, relics and other drops."""
    c = Canvas(18, 18)
    _shadow(c, 9, 15, 6, 1.8)
    glow = GOLD if kind == "relic" else ramp("#f4f1ff", "#c9a2ff", "#8a5ae8", "#4a2f9a")
    for y in range(0, 15):
        for x in range(0, 18):
            d = ((x - 9) / 8) ** 2 + ((y - 9) / 7) ** 2
            if d <= 1:
                c.blend(x, y, glow[1][:3] + (int(60 * (1 - d)),))
    if kind == "relic":
        c.ellipse(9, 10, 4, 4, GOLD[1])
        c.ellipse(9, 10, 2, 2, hex_color("#5fd6ff"))
        c.put(8, 9, hex_color("#ffffff"))
        c.hline(5, 13, 6, GOLD[2])
    else:
        bag = ramp("#e3c286", "#b3824f", "#81573d")
        c.ellipse(9, 10.5, 4.5, 3.8, bag[1])
        c.rect(7, 5, 5, 2, bag[0])
        c.hline(7, 11, 7, bag[2])
        c.put(7, 9, bag[0])
    for x, y in ((3, 3), (15, 5), (14, 2)):
        c.put(x, y, glow[0])
    _finish(c)
    return c, (9, 14)


def gate(night: bool) -> tuple[Canvas, tuple[int, int]]:
    """Wooden archway framing a shimmering path to the next region."""
    c = Canvas(34, 44)
    _shadow(c, 17, 40, 15, 3)
    portal = ramp("#e2fffb", "#8ff7ef", "#3fd6d0", "#1f8a8a") if night else ramp("#fffbe0", "#c8f0a0", "#7fcf6a", "#3f8f5a")
    for y in range(10, 40):
        for x in range(7, 27):
            t = (y - 10) / 30
            col = portal[1] if (x + y) % 5 == 0 else portal[2]
            c.blend(x, y, col[:3] + (int(170 * (1 - t * 0.6)),))
    for px in (4, 26):
        for y in range(8, 41):
            c.put(px, y, WOOD[0] if px == 4 else WOOD[2])
            c.put(px + 1, y, WOOD[1])
            c.put(px + 2, y, WOOD[1] if px == 4 else WOOD[2])
    for y in range(4, 10):
        for x in range(2, 32):
            c.put(x, y, WOOD[0] if y < 6 else WOOD[1])
    c.hline(2, 31, 9, WOOD[2])
    leaves = ramp("#b8f07a", "#6fc24c", "#3f8a3e")
    for x in range(2, 32, 2):
        c.put(x, 3 + (x % 3 == 0), leaves[1])
        c.put(x + 1, 4, leaves[0])
    for y in range(12, 38, 3):
        c.put(4, y, leaves[1])
        c.put(28, y + 1, leaves[2])
    for x, y in ((12, 18), (20, 24), (15, 31), (22, 14)):
        c.put(x, y, portal[0])
    _finish(c)
    return c, (17, 39)


def marker(kind: str) -> tuple[Canvas, tuple[int, int]]:
    """Floating quest markers: '!' new quest, '?' ready to turn in, '*' service."""
    c = Canvas(11, 15)
    gold = ramp("#fff6c0", "#ffd45c", "#e0962e", "#8a4a22")
    blue = ramp("#e8fbff", "#8fe0ff", "#3f9ae0", "#25407a")
    pal = blue if kind == "service" else gold
    glyphs = {
        "quest": ["..###..", "..###..", "..###..", "..###..", "..##...", "..##...", ".......", "..##...", "..##..."],
        "ready": [".#####.", "###.###", "....###", "...###.", "..###..", "..##...", ".......", "..##...", "..##..."],
        "service": ["...#...", "...#...", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "...#...", "...#..."],
    }
    rows = glyphs[kind]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                shade = 0 if y < 2 or (x < 3 and y < 5) else (1 if y < 6 else 2)
                c.put(x + 2, y + 2, pal[shade])
    c.outline(pal[3])
    solid = Canvas(c.w, c.h)
    solid.px = c.px.copy()
    solid.outline(OUTLINE)
    c.px = solid.px
    return c, (5, 14)


def crystal_altar(pal, seed: int = 9) -> tuple[Canvas, tuple[int, int]]:
    """Ancient altar in the cave holding a huge humming crystal."""
    rng = random.Random(seed)
    stone, crystal = pal["stone"], pal["crystal"]
    c = Canvas(64, 70)
    origin = (32, 64)
    for y in range(56, 70):
        for x in range(64):
            if ((x - 32) / 30) ** 2 + ((y - 63) / 5) ** 2 <= 1:
                c.blend(x, y, pal["shadow"])
    _block(c, 10, 50, 44, 12, stone, top=4)
    _block(c, 16, 42, 32, 10, stone, top=3)
    for x in range(12, 52, 6):
        c.put(x, 58, stone[1])
    # Big central crystal.
    for y in range(6, 44):
        p = (y - 6) / 38
        half = 7 * min(1.0, p * 2.2 + 0.1)
        for x in range(int(32 - half), int(32 + half) + 1):
            rel = (x + 0.5 - (32 - half)) / (2 * half + 0.01)
            level = 0 if rel < 0.25 else (1 if rel < 0.5 else (2 if rel < 0.78 else 3))
            c.put(x, y, crystal[level])
    for x, y in ((29, 14), (30, 15), (34, 24), (31, 30)):
        c.put(x, y, crystal[0])
    for sx in (22, 42):
        for y in range(30, 43):
            c.put(sx, y, crystal[1])
            c.put(sx + 1, y, crystal[3])
    c.outline(pal["outline"])
    for y in range(0, 60):
        for x in range(64):
            if c.alpha(x, y) == 255:
                continue
            d = ((x - 32) / 30) ** 2 + ((y - 26) / 28) ** 2
            if d <= 1:
                c.blend(x, y, crystal[2][:3] + (int(50 * (1 - d)),))
    for _ in range(10):
        x, y = rng.randrange(6, 58), rng.randrange(2, 40)
        if c.alpha(x, y) < 255:
            c.put(x, y, crystal[0])
    return c, origin


def cave_gate() -> tuple[Canvas, tuple[int, int]]:
    """Rough rock archway with a violet shimmer."""
    stone = ramp("#9690b8", "#67638a", "#4a4664", "#34304a", "#221f33")
    portal = ramp("#f6f0ff", "#d0b8ff", "#9a7aff", "#5a3ac0")
    c = Canvas(36, 46)
    _shadow(c, 18, 42, 16, 3)
    for y in range(10, 42):
        for x in range(8, 28):
            c.blend(x, y, portal[2][:3] + (int(150 * (1 - (y - 10) / 40)),))
    for y in range(4, 43):
        for x in range(2, 34):
            inside = ((x - 18) / 10.5) ** 2 + ((y - 30) / 22) ** 2 <= 1 and y > 10
            ring = ((x - 18) / 16) ** 2 + ((y - 28) / 25) ** 2 <= 1
            if ring and not inside:
                lit = (18 - x) * 0.4 + (20 - y) * 0.3
                c.put(x, y, stone[0] if lit > 5 else (stone[1] if lit > 0 else (stone[2] if lit > -5 else stone[3])))
    for x, y in ((13, 20), (22, 16), (17, 30), (20, 36)):
        c.put(x, y, portal[0])
    _finish(c)
    return c, (18, 41)


def key_badge() -> tuple[Canvas, tuple[int, int]]:
    """A keycap with the letter E, shown above interactable objects."""
    c = Canvas(13, 13)
    cap = ramp("#fff6e0", "#e8dcc0", "#b8a888", "#7a6a58")
    for y in range(1, 12):
        for x in range(1, 12):
            corner = (x in (1, 11)) and (y in (1, 11))
            if corner:
                continue
            c.put(x, y, cap[2] if y >= 10 else cap[1])
    c.hline(2, 10, 1, cap[0])
    ink = hex_color("#2a1d33")
    for y in range(3, 9):
        c.put(4, y, ink)
    for x in range(4, 9):
        c.put(x, 3, ink)
        c.put(x, 8, ink)
    for x in range(4, 8):
        c.put(x, 5, ink)
        c.put(x, 6, ink) if False else None
    c.outline(OUTLINE)
    return c, (6, 12)


def sky_shard() -> tuple[Canvas, tuple[int, int]]:
    """A fallen fragment of a sky island: glowing shard in a scorched crater."""
    c = Canvas(30, 28)
    dirt = ramp("#5e3d33", "#3f2a2c", "#2a1b22")
    for y in range(18, 27):
        for x in range(1, 29):
            d = ((x + 0.5 - 15) / 13.5) ** 2 + ((y + 0.5 - 22) / 4.5) ** 2
            if d <= 1:
                c.put(x, y, dirt[2] if d < 0.45 else (dirt[1] if d < 0.8 else dirt[0]))
    glow = ramp("#ffffff", "#d8fbff", "#8fe0ff", "#3a8ac8")
    for y in range(2, 23):
        p = (y - 2) / 21
        half = 5 * min(1.0, p * 2.0 + 0.15)
        cx = 15 + (1 - p) * 3
        for x in range(int(cx - half), int(cx + half) + 1):
            rel = (x + 0.5 - (cx - half)) / (2 * half + 0.01)
            c.put(x, y, glow[0] if rel < 0.25 else (glow[1] if rel < 0.55 else (glow[2] if rel < 0.85 else glow[3])))
    for x, y in ((8, 20), (21, 19), (11, 22), (19, 23)):
        c.put(x, y, glow[2])
        c.put(x, y - 1, glow[1])
    _finish(c)
    for y in range(0, 26):
        for x in range(30):
            if c.alpha(x, y) == 255:
                continue
            d = ((x + 0.5 - 16) / 15) ** 2 + ((y + 0.5 - 12) / 13) ** 2
            if d <= 1:
                c.blend(x, y, glow[2][:3] + (int(55 * (1 - d)),))
    return c, (15, 23)


def rune_circle(colors=("#f6f0ff", "#d0b8ff", "#9a7aff", "#5a3ac0")) -> tuple[Canvas, tuple[int, int]]:
    """Glowing rune ring on the floor (crystal altar, storm heart)."""
    c = Canvas(40, 18)
    glow = ramp(*colors)
    for y in range(18):
        for x in range(40):
            d = ((x + 0.5 - 20) / 19) ** 2 + ((y + 0.5 - 9) / 8) ** 2
            if 0.72 <= d <= 1.0:
                c.put(x, y, glow[1] if (x + y) % 4 else glow[0])
            elif d < 0.72:
                c.blend(x, y, glow[2][:3] + (int(70 * (1 - d)),))
    for x, y in ((12, 9), (20, 5), (28, 9), (20, 13)):
        c.put(x, y, glow[0])
        c.put(x + 1, y, glow[1])
    return c, (20, 9)


def sky_archive(pal, seed: int = 11) -> tuple[Canvas, tuple[int, int]]:
    """Marble archive of the Keepers: columns, blue roof, glowing doorway."""
    stone = pal["stone"]
    roof = ramp("#c6e0ff", "#86b2ec", "#4a7ac8", "#2a4a8a", "#1a2a5a")
    glow = ramp("#ffffff", "#c8fff4", "#6fe0c8")
    c = Canvas(170, 130)
    origin = (85, 124)
    for y in range(114, 130):
        for x in range(170):
            if ((x - 87) / 82) ** 2 + ((y - 122) / 7) ** 2 <= 1:
                c.blend(x, y, pal["shadow"])
    _block(c, 8, 108, 154, 14, stone, top=4)       # stairs base
    _block(c, 16, 100, 138, 10, stone, top=3)
    _block(c, 22, 52, 126, 50, stone, top=0)        # main wall
    for x in range(30, 145, 6):
        c.vline(x, 54, 98, stone[2])
    # Columns.
    for cx in (28, 52, 110, 134):
        _block(c, cx - 5, 44, 11, 58, stone, top=3)
        c.vline(cx - 3, 48, 98, stone[5])
        _block(c, cx - 7, 40, 15, 6, stone, top=2)
    # Roof (pediment).
    for y in range(14, 46):
        half = (y - 14) * 2.6
        for x in range(int(85 - half), int(85 + half) + 1):
            level = 0 if x < 85 - half + 4 else (1 if x < 85 else (2 if x < 85 + half - 3 else 3))
            c.put(x, y, roof[level])
    c.hline(8, 162, 46, roof[3])
    c.hline(8, 162, 47, roof[4])
    # Glowing doorway and a sky-seal emblem.
    for y in range(66, 100):
        for x in range(72, 99):
            if y < 74 and (x - 85) ** 2 + ((y - 74) * 1.6) ** 2 > 170:
                continue
            c.put(x, y, glow[2] if (x + y) % 3 else glow[1])
    c.ellipse(85, 30, 5, 5, glow[1])
    c.ellipse(85, 30, 2.5, 2.5, glow[0])
    c.outline(pal["outline"])
    return c, origin


def sky_gate() -> tuple[Canvas, tuple[int, int]]:
    """Bridge of light: a glowing arch at the island's edge."""
    c = Canvas(36, 48)
    glow = ramp("#ffffff", "#fff6c0", "#ffd45c", "#e0962e")
    for y in range(4, 46):
        for x in range(4, 32):
            d = ((x - 18) / 13) ** 2 + ((y - 30) / 26) ** 2
            if d <= 1:
                c.blend(x, y, glow[1][:3] + (int(160 * (1 - d)) + 40,))
    for y in range(8, 46):
        for x in (6, 29):
            c.put(x, y, glow[2])
            c.put(x + 1, y, glow[1])
    for x in range(6, 31):
        y = 8 + int(abs(x - 18) * 0.25)
        c.put(x, y, glow[0])
    _finish(c)
    return c, (18, 44)


def app_icon() -> Canvas:
    """128x128 game icon: a floating island with a glowing sky shard, at 4x."""
    small = Canvas(32, 32)
    sky = ramp("#2a3a7a", "#3a5aa8", "#5a86d0", "#86b2ec", "#b8d6f6")
    for y in range(32):
        for x in range(32):
            if (x - 15.5) ** 2 + (y - 15.5) ** 2 <= 15.5 ** 2:
                small.put(x, y, sky[min(4, y // 7)])
    grass = ramp("#e6f6c6", "#92d08e", "#4f9a72", "#2a5a5a")
    rock = ramp("#b8bdd2", "#9094b0", "#6a6c8a", "#4a4a66")
    for y in range(17, 29):
        half = 11 - (y - 17) * 0.95 if y > 19 else 11
        for x in range(int(16 - half), int(16 + half) + 1):
            small.put(x, y, (grass[0] if y == 17 else grass[1] if y < 19 else grass[2]) if y < 20 else rock[min(3, (y - 20) // 2)])
    glow = ramp("#ffffff", "#fff6c0", "#ffd45c", "#e0962e")
    for y in range(5, 17):
        half = (y - 5) * 0.45 if y < 12 else (17 - y) * 0.9
        for x in range(int(16 - half), int(16 + half) + 1):
            small.put(x, y, glow[0] if x < 16 else glow[2])
    for x, y in ((9, 8), (23, 6), (25, 12), (7, 13)):
        small.put(x, y, glow[1])
    small.outline(hex_color("#1a1a3a"))
    big = Canvas(128, 128)
    big.px = small.px.repeat(4, axis=0).repeat(4, axis=1)
    return big
