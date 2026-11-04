"""Title-screen art: a big floating island seen from the side (grassy top
with trees, a tiny village and a waterfall over the rim, a tapering rocky
underside with hanging roots) and small satellite islands."""
from __future__ import annotations

import math
import random

import numpy as np

from pixel import Canvas, fbm, hex_color
from palettes import STYLES

DAY = STYLES["day"]
OUTLINE = hex_color("#2a1a2c")


def _outline(c: Canvas) -> None:
    solid = c.px[:, :, 3] == 255
    edge = np.zeros_like(solid)
    edge[1:, :] |= solid[:-1, :]
    edge[:-1, :] |= solid[1:, :]
    edge[:, 1:] |= solid[:, :-1]
    edge[:, :-1] |= solid[:, 1:]
    c.px[edge & ~solid] = OUTLINE


def island(w: int, h: int, top_rx: float, top_ry: float, depth: float, seed: int,
           trees: int, houses: int, waterfall: bool) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(w, h)
    grass, dirt, stone, leaf, water = DAY["grass"], DAY["dirt"], DAY["stone"], DAY["leaf"], DAY["water"]
    cx, cy = w / 2, top_ry + 6
    under_noise = fbm(w, 1, 9.0, seed + 5, 3)[0]
    grain = fbm(w, h, 4.0, seed + 7, 2)
    # Underside: a rocky cone below the grass ellipse, lit from the left.
    for x in range(w):
        dx = (x + 0.5 - cx) / top_rx
        if abs(dx) >= 1:
            continue
        half = math.sqrt(1 - dx * dx)
        rim = cy + top_ry * half
        bottom = cy + depth * half ** 1.6 * (0.8 + 0.4 * under_noise[x]) + rng.choice((0, 0, 2, 4, -2))
        for y in range(int(rim) - 2, int(bottom)):
            t = (y - rim) / max(1.0, bottom - rim)
            if y < rim + 5:
                color = dirt[3] if y < rim + 2 else dirt[2]
            else:
                light = 4 - int(t * 3.2) - (1 if dx > 0.25 else 0) - (1 if grain[y, x] < 0.4 else 0)
                band = ((y + int(under_noise[x] * 9)) // 11) % 4 == 0 and t < 0.7
                color = stone[max(1, min(5, light))] if not band else dirt[max(1, min(4, light))]
            c.put(x, y, color)
    # Hanging roots.
    for _ in range(int(top_rx / 3)):
        x = int(cx + rng.uniform(-0.9, 0.9) * top_rx)
        dx = (x - cx) / top_rx
        rim = cy + top_ry * math.sqrt(max(0.0, 1 - dx * dx))
        for i in range(rng.randint(4, int(14 + depth / 10))):
            c.put(x + (1 if i > 6 and rng.random() < 0.3 else 0), int(rim) + 4 + i, leaf[rng.randint(1, 3)])
    # Grass top with a lighter crown and darker back rim.
    shade = fbm(w, h, 10.0, seed + 9, 2)
    for y in range(int(cy - top_ry) - 1, int(cy + top_ry) + 2):
        for x in range(w):
            if ((x + 0.5 - cx) / top_rx) ** 2 + ((y + 0.5 - cy) / top_ry) ** 2 <= 1:
                level = 3 + (1 if shade[y, x] > 0.55 else 0) - (1 if shade[y, x] < 0.38 else 0)
                if y < cy - top_ry * 0.6:
                    level += 1
                c.put(x, y, grass[max(1, min(6, level))])
    for x in range(w):
        dx = (x + 0.5 - cx) / top_rx
        if abs(dx) < 1:
            c.put(x, int(cy + top_ry * math.sqrt(1 - dx * dx)), grass[2])
    # Waterfall from a little pond near the front rim.
    if waterfall:
        wx = int(cx + top_rx * 0.42)
        dx = (wx - cx) / top_rx
        rim = cy + top_ry * math.sqrt(1 - dx * dx)
        c.ellipse(wx - 10, rim - 9, 12, 4.0, water[2])
        c.ellipse(wx - 11, rim - 10, 8, 2.2, water[3])
        c.rect(wx - 3, int(rim - 7), 7, 8, water[3])
        for y in range(int(rim - 1), int(cy + depth * 1.05)):
            for k in range(-3, 4):
                fade = (y - rim) / (depth * 0.9)
                if rng.random() < fade * 0.6:
                    continue
                color = water[4] if (y + k * 3) % 5 else water[5]
                c.put(wx + k, y, color if abs(k) < 3 else water[3])
    # Houses (tiny, red roofs) and trees, back to front.
    things = []
    for _ in range(houses):
        things.append(("house", cx + rng.uniform(-0.45, 0.35) * top_rx, cy + rng.uniform(-0.35, 0.3) * top_ry))
    for _ in range(trees):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.uniform(0.15, 0.92))
        things.append(("tree", cx + math.cos(a) * r * top_rx * 0.92, cy + math.sin(a) * r * top_ry * 0.8))
    for kind, x, y in sorted(things, key=lambda t: t[2]):
        x, y = int(x), int(y)
        if kind == "tree":
            size = rng.randint(4, 7)
            c.rect(x, y - 3, 2, 4, DAY["bark"][2])
            c.ellipse(x + 1, y - 3 - size * 0.7, size, size * 0.85, leaf[2])
            c.ellipse(x, y - 4 - size * 0.8, size * 0.7, size * 0.6, leaf[4])
            c.put(x - 1, y - 5 - size, leaf[5])
        else:
            c.rect(x - 5, y - 6, 11, 7, hex_color("#efe2c4"))
            c.rect(x - 5, y - 6, 11, 1, hex_color("#c8b68e"))
            for i in range(4):
                c.hline(x - 6 + i, x + 6 - i, y - 7 - i, hex_color("#c0563a") if i % 2 == 0 else hex_color("#a8442e"))
            c.rect(x - 1, y - 3, 2, 3, hex_color("#5a3a2a"))
            c.put(x + 3, y - 4, hex_color("#ffe08a"))
    _outline(c)
    return c


def build() -> dict[str, Canvas]:
    return {
        "ui/title_island.png": island(380, 290, 168, 48, 180, 41, trees=46, houses=5, waterfall=True),
        "ui/title_islet_0.png": island(110, 110, 46, 14, 70, 52, trees=6, houses=0, waterfall=False),
        "ui/title_islet_1.png": island(80, 80, 32, 10, 52, 63, trees=4, houses=1, waterfall=False),
    }
