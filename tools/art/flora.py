"""Trees, bushes and canopy clusters with sphere shading and cluster outlines."""
from __future__ import annotations

import math
import random

import numpy as np

from pixel import Canvas, fbm, light_level


def _canopy(canvas: Canvas, blobs, pal, rng: random.Random, glow=None) -> None:
    """Draws overlapping leaf clusters. Later blobs sit in front of earlier ones."""
    leaf = pal["leaf"]
    outline = pal["outline"]
    h, w = canvas.h, canvas.w
    owner = np.full((h, w), -1, dtype=int)
    for index, (cx, cy, r) in enumerate(blobs):
        y0, y1 = max(0, int(cy - r - 1)), min(h, int(cy + r + 2))
        x0, x1 = max(0, int(cx - r - 1)), min(w, int(cx + r + 2))
        for y in range(y0, y1):
            for x in range(x0, x1):
                # Slightly lumpy circles read as foliage rather than balls.
                angle = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                wobble = 1.0 + 0.07 * math.sin(angle * 5 + index * 1.7) + 0.04 * math.sin(angle * 9 + index)
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r * wobble:
                    owner[y, x] = index
    texture = fbm(w, h, 3.0, rng.randrange(10_000), 2)
    for y in range(h):
        for x in range(w):
            index = owner[y, x]
            if index < 0:
                continue
            cx, cy, r = blobs[index]
            nx = (x + 0.5 - cx) / r
            ny = (y + 0.5 - cy) / r
            nz = math.sqrt(max(0.0, 1.0 - min(1.0, nx * nx + ny * ny)))
            shade = light_level(nx, ny, nz)
            shade += (texture[y, x] - 0.5) * 0.45
            # Lower clusters and the underside of the whole crown fall into shade.
            level = int(np.clip(shade * 5.2 + 0.4, 1, 6))
            canvas.px[y, x] = leaf[level]
    # Cluster separation: a dark line where a front blob overlaps a back blob.
    for y in range(1, h):
        for x in range(w):
            here, above = owner[y, x], owner[y - 1, x]
            if here >= 0 and above >= 0 and here != above and here > above:
                canvas.px[y - 1, x] = leaf[1]
    # Leaf sparkle on the lit side.
    for _ in range(len(blobs) * 6):
        index = rng.randrange(len(blobs))
        cx, cy, r = blobs[index]
        angle = rng.uniform(math.pi * 1.0, math.pi * 1.6)
        dist = rng.uniform(0.3, 0.8) * r
        x, y = int(cx + math.cos(angle) * dist), int(cy + math.sin(angle) * dist)
        if canvas.inside(x, y) and owner[y, x] == index:
            canvas.put(x, y, leaf[6])
            if glow is not None and rng.random() < 0.35:
                canvas.put(x, y, glow[rng.randrange(len(glow))])
    canvas.outline(outline)


def tree(seed: int, pal, size: str = "large", glow=None) -> tuple[Canvas, tuple[int, int]]:
    """Returns (canvas, origin) where origin is the trunk base in canvas pixels."""
    rng = random.Random(seed)
    width, height = (72, 84) if size == "large" else (56, 66)
    canvas = Canvas(width, height)
    base_x, base_y = width // 2, height - 8
    crown_r = 21 if size == "large" else 16
    trunk_h = 20 if size == "large" else 15
    # Ground shadow (soft, offset towards bottom-right like a late-morning sun).
    shadow = pal["shadow"]
    for y in range(base_y - 6, base_y + 7):
        for x in range(base_x - crown_r - 2, base_x + crown_r + 8):
            dx = (x + 0.5 - (base_x + 4)) / (crown_r + 2)
            dy = (y + 0.5 - (base_y + 1)) / 5.5
            if dx * dx + dy * dy <= 1.0:
                canvas.blend(x, y, shadow)
    bark = pal["bark"]
    # Trunk with flared roots, lit from the left.
    for y in range(base_y - trunk_h, base_y + 1):
        t = (y - (base_y - trunk_h)) / trunk_h
        half = 3 + (2.5 * t * t if t > 0.65 else 0)
        for x in range(int(base_x - half), int(base_x + half) + 1):
            rel = (x - (base_x - half)) / (2 * half + 0.01)
            level = 3 if rel < 0.3 else (2 if rel < 0.7 else 1)
            if (y * 7 + x * 3) % 11 == 0:
                level = max(0, level - 1)
            canvas.put(x, y, bark[level])
    canvas.put(base_x - 1, base_y - trunk_h + 6, bark[0])
    canvas.put(base_x + 1, base_y - trunk_h + 11, bark[0])
    # Crown: a back layer, a main mass and smaller front clusters.
    cy = base_y - trunk_h - crown_r + 6
    blobs = []
    for _ in range(4):
        blobs.append((base_x + rng.uniform(-crown_r * 0.6, crown_r * 0.6), cy - crown_r * 0.45 + rng.uniform(-3, 2), crown_r * rng.uniform(0.5, 0.62)))
    blobs.append((base_x + rng.uniform(-2, 2), cy, crown_r * 0.82))
    for side in (-1, 1):
        blobs.append((base_x + side * crown_r * rng.uniform(0.55, 0.72), cy + rng.uniform(1, 5), crown_r * rng.uniform(0.48, 0.58)))
    blobs.append((base_x + rng.uniform(-4, 4), cy + crown_r * 0.45, crown_r * 0.5))
    crown = Canvas(width, height)
    _canopy(crown, blobs, pal, rng, glow)
    canvas.paste(crown, 0, 0)
    return canvas, (base_x, base_y)


def bush(seed: int, pal, glow=None) -> tuple[Canvas, tuple[int, int]]:
    rng = random.Random(seed)
    canvas = Canvas(28, 22)
    base_x, base_y = 14, 18
    for y in range(base_y - 2, base_y + 3):
        for x in range(2, 27):
            if ((x + 0.5 - 15) / 11) ** 2 + ((y + 0.5 - base_y) / 2.6) ** 2 <= 1:
                canvas.blend(x, y, pal["shadow"])
    blobs = [(base_x - 5 + rng.uniform(-1, 1), base_y - 7, 6.5), (base_x + 5, base_y - 7 + rng.uniform(-1, 1), 6),
             (base_x, base_y - 9, 7), (base_x - 1, base_y - 4, 5.5)]
    crown = Canvas(28, 22)
    _canopy(crown, blobs, pal, rng, glow)
    canvas.paste(crown, 0, 0)
    if glow is None and rng.random() < 0.6:
        berry = pal["flowers"][rng.randrange(len(pal["flowers"]))]
        for _ in range(3):
            x, y = base_x + rng.randint(-7, 7), base_y - rng.randint(5, 13)
            if crown.alpha(x, y) and crown.get(x, y)[:3] != pal["outline"][:3]:
                canvas.put(x, y, berry[0])
    return canvas, (base_x, base_y)


def canopy_border(width: int, height: int, pal, seed: int, depth: int = 26, glow=None) -> Canvas:
    """Dense foliage that frames the map edges and is drawn above actors."""
    rng = random.Random(seed)
    blobs = []
    step = 14
    for x in range(-10, width + 20, step):
        blobs.append((x + rng.uniform(-4, 4), rng.uniform(-6, depth * 0.35), rng.uniform(13, 19)))
        blobs.append((x + rng.uniform(-4, 4), height - rng.uniform(-6, depth * 0.35), rng.uniform(13, 19)))
    for y in range(-10, height + 20, step):
        blobs.append((rng.uniform(-6, depth * 0.35), y + rng.uniform(-4, 4), rng.uniform(13, 19)))
        blobs.append((width - rng.uniform(-6, depth * 0.35), y + rng.uniform(-4, 4), rng.uniform(13, 19)))
    canvas = Canvas(width, height)
    # Render the border in tiles to keep the per-pixel loops fast.
    tile = 96
    for ty in range(0, height, tile):
        for tx in range(0, width, tile):
            if depth + 24 < tx < width - depth - 24 - tile and depth + 24 < ty < height - depth - 24 - tile:
                continue
            local = [(bx - tx + 24, by - ty + 24, r) for bx, by, r in blobs
                     if tx - 30 <= bx <= tx + tile + 30 and ty - 30 <= by <= ty + tile + 30]
            if not local:
                continue
            part = Canvas(tile + 48, tile + 48)
            _canopy(part, local, pal, rng, glow)
            region = part.px[24:24 + tile, 24:24 + tile]
            h = min(tile, height - ty)
            w = min(tile, width - tx)
            dest = canvas.px[ty:ty + h, tx:tx + w]
            m = region[:h, :w, 3] > 0
            dest[m] = region[:h, :w][m]
    return canvas
