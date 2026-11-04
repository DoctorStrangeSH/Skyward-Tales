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
    # Sized for the chibi cast (~24 px tall heroes).
    width, height = (58, 68) if size == "large" else (46, 54)
    canvas = Canvas(width, height)
    base_x, base_y = width // 2, height - 8
    crown_r = 17 if size == "large" else 13
    trunk_h = 15 if size == "large" else 11
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


def crystal_cluster(seed: int, pal, size: str = "large") -> tuple[Canvas, tuple[int, int]]:
    """Glowing crystal formation used in caves instead of trees."""
    rng = random.Random(seed)
    width, height = (48, 64) if size == "large" else (36, 46)
    canvas = Canvas(width, height)
    base_x, base_y = width // 2, height - 6
    for y in range(base_y - 4, base_y + 5):
        for x in range(2, width - 2):
            dx = (x + 0.5 - base_x) / (width / 2 - 3)
            dy = (y + 0.5 - base_y) / 4
            if dx * dx + dy * dy <= 1:
                canvas.blend(x, y, pal["shadow"])
    crystal = pal["crystal"]
    count = 5 if size == "large" else 3
    shards = []
    for i in range(count):
        t = (i - (count - 1) / 2) / max(1, count - 1)
        h = (height - 14) * (1 - abs(t) * 0.55) * rng.uniform(0.75, 1.0)
        w = rng.uniform(3.5, 5.5)
        lean = t * rng.uniform(4, 9)
        shards.append((base_x + t * width * 0.45, h, w, lean))
    shards.sort(key=lambda s: -s[1])  # tallest at the back
    for sx, h, w, lean in shards:
        top = base_y - h
        for y in range(int(top), base_y + 1):
            p = (y - top) / max(1, h)
            cx = sx + lean * (1 - p)
            half = w * min(1.0, p * 3.0 + 0.15)
            for x in range(int(cx - half), int(cx + half) + 1):
                rel = (x + 0.5 - (cx - half)) / (2 * half + 0.01)
                level = 0 if rel < 0.22 else (1 if rel < 0.5 else (2 if rel < 0.8 else 3))
                if p > 0.85:
                    level = min(4, level + 1)
                canvas.put(x, y, crystal[level])
        canvas.put(int(sx + lean), int(top) + 1, crystal[0])
    # Rocky base.
    rock = pal["stone"]
    for x in range(base_x - width // 3, base_x + width // 3):
        for y in range(base_y - 3, base_y + 1):
            if (x * 7 + y * 3) % 5 and abs(x - base_x) < width // 3 - (base_y - y):
                canvas.put(x, y, rock[3] if y == base_y - 3 else rock[2])
    canvas.outline(pal["outline"])
    # Soft glow halo, added after the outline so it has no hard edge.
    glow = pal["crystal"][2]
    for y in range(height):
        for x in range(width):
            if canvas.alpha(x, y) == 255:
                continue
            d = ((x + 0.5 - base_x) / (width * 0.5)) ** 2 + ((y + 0.5 - (base_y - height * 0.35)) / (height * 0.5)) ** 2
            if d <= 1:
                canvas.blend(x, y, glow[:3] + (int(38 * (1 - d)),))
    return canvas, (base_x, base_y)


def rock_pile(seed: int, pal) -> tuple[Canvas, tuple[int, int]]:
    """Small cave boulders with a crystal shard (decor, like bushes)."""
    rng = random.Random(seed)
    canvas = Canvas(26, 20)
    base_x, base_y = 13, 16
    stone = pal["stone"]
    for cx, cy, r in ((9, 12, 5.5), (16, 11, 6), (13, 14, 5)):
        for y in range(canvas.h):
            for x in range(canvas.w):
                d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.2)
                if d <= r:
                    lit = (cx - x) * 0.6 + (cy - y) * 0.8
                    canvas.put(x, y, stone[4] if lit > 2.5 else (stone[3] if lit > -1.5 else stone[2]))
    crystal = pal["crystal"]
    sx = 13 + rng.randint(-4, 4)
    for i in range(6):
        canvas.put(sx, 8 - i, crystal[1] if i < 4 else crystal[0])
        canvas.put(sx + 1, 8 - i, crystal[2])
    canvas.outline(pal["outline"])
    return canvas, (base_x, base_y)


def stone_spire(seed: int, pal, size: str = "large") -> tuple[Canvas, tuple[int, int]]:
    """Tall wind-carved stone needle with grass ledges (Wind Spires 'trees')."""
    rng = random.Random(seed)
    width, height = (34, 86) if size == "large" else (28, 60)
    canvas = Canvas(width, height)
    base_x, base_y = width // 2, height - 5
    for y in range(base_y - 3, base_y + 4):
        for x in range(width):
            d = ((x + 0.5 - base_x) / (width / 2 - 1)) ** 2 + ((y + 0.5 - base_y) / 3.2) ** 2
            if d <= 1:
                canvas.blend(x, y, pal["shadow"])
    stone, grass = pal["stone"], pal["grass"]
    top = 3
    lean = rng.uniform(-3, 3)
    bands = [rng.uniform(0.25, 0.4), rng.uniform(0.55, 0.7)]
    for y in range(top, base_y + 1):
        p = (y - top) / (base_y - top)
        cx = base_x + lean * (1 - p)
        half = (width / 2 - 3) * (0.35 + 0.65 * p ** 0.7)
        half += math.sin(y * 0.5 + seed) * 0.8
        for x in range(int(cx - half), int(cx + half) + 1):
            rel = (x + 0.5 - (cx - half)) / (2 * half + 0.01)
            level = 4 if rel < 0.2 else (3 if rel < 0.45 else (2 if rel < 0.75 else 1))
            if (y + int(x * 0.5)) % 7 == 0:
                level = max(0, level - 1)
            canvas.put(x, y, stone[level])
        if any(abs(p - b) < 0.025 for b in bands):
            for x in range(int(cx - half) - 1, int(cx + half) + 2):
                canvas.put(x, y, grass[5] if x < cx else grass[4])
    for x in range(int(base_x + lean - 3), int(base_x + lean + 4)):
        canvas.put(x, top, grass[6])
        canvas.put(x, top + 1, grass[5])
    canvas.outline(pal["outline"])
    return canvas, (base_x, base_y)


def palm(seed: int, pal, size: str = "large") -> tuple[Canvas, tuple[int, int]]:
    """Leaning palm: ringed trunk and a crown of drooping fronds."""
    rng = random.Random(seed)
    width, height = (50, 64) if size == "large" else (42, 52)
    c = Canvas(width, height)
    base_x, base_y = width // 2, height - 6
    for y in range(base_y - 2, base_y + 3):
        for x in range(4, width - 4):
            if ((x + 0.5 - base_x) / 9) ** 2 + ((y + 0.5 - base_y) / 2.4) ** 2 <= 1:
                c.blend(x, y, pal["shadow"])
    lean = rng.choice([-1, 1]) * rng.uniform(6, 10)
    top_y = 15 if size == "large" else 12
    bark = pal["bark"]
    steps = base_y - top_y
    for i in range(steps):
        t = i / steps
        x = base_x + lean * (t ** 1.6)
        y = base_y - i
        half = 2.6 - t * 0.8
        for xx in range(int(x - half), int(x + half) + 1):
            ring = (i % 4 == 0)
            c.put(xx, y, bark[1] if ring else (bark[3] if xx < x else bark[2]))
    cx, cy = base_x + lean, top_y
    leaf = pal["leaf"]
    for k in range(7):
        ang = -math.pi / 2 + (k - 3) * 0.55 + rng.uniform(-0.1, 0.1)
        length = rng.uniform(13, 18) if size == "large" else rng.uniform(10, 13)
        for j in range(int(length)):
            t = j / length
            x = cx + math.cos(ang) * j * 1.1
            y = cy + math.sin(ang) * j * 0.6 + (t ** 2) * 10
            for w in range(-1, 2):
                c.put(round(x), round(y + w * (1 - t)), leaf[4] if w < 0 else (leaf[3] if w == 0 else leaf[2]))
    for dx, dy in ((-2, 2), (2, 3), (0, 4)):
        c.ellipse(cx + dx, cy + dy, 1.6, 1.6, bark[1])
    c.outline(pal["outline"])
    return c, (base_x, base_y)


def pine(seed: int, pal, size: str = "large") -> tuple[Canvas, tuple[int, int]]:
    """Snow-tipped fir: stacked tiers over a short trunk."""
    rng = random.Random(seed)
    width, height = (40, 68) if size == "large" else (32, 52)
    c = Canvas(width, height)
    base_x, base_y = width // 2, height - 6
    for y in range(base_y - 2, base_y + 3):
        for x in range(4, width - 4):
            if ((x + 0.5 - base_x) / 12) ** 2 + ((y + 0.5 - base_y) / 2.6) ** 2 <= 1:
                c.blend(x, y, pal["shadow"])
    bark, leaf = pal["bark"], pal["leaf"]
    c.rect(base_x - 2, base_y - 10, 4, 10, bark[2])
    c.vline(base_x - 2, base_y - 10, base_y - 1, bark[3])
    tiers = 4 if size == "large" else 3
    top = 4
    span = base_y - 8 - top
    for t in range(tiers):
        y0 = top + int(span * t / tiers * 0.9)
        y1 = top + int(span * (t + 1) / tiers) + 4
        for y in range(y0, y1):
            p = (y - y0) / max(1, y1 - y0)
            half = (3 + (t + 1) * (width / 2 - 5) / tiers) * (0.25 + 0.75 * p)
            for x in range(int(base_x - half), int(base_x + half) + 1):
                rel = (x - (base_x - half)) / (2 * half + 0.01)
                shade = 5 if rel < 0.25 else (4 if rel < 0.5 else (3 if rel < 0.8 else 2))
                if y == y1 - 1:
                    shade = 1
                c.put(x, y, leaf[shade])
            # Snow rests on the upper edge of each tier, thicker on the lit side.
            if y - y0 < 2:
                for x in range(int(base_x - half), int(base_x + half * 0.4) + 1):
                    c.put(x, y, pal["grass"][6] if y == y0 or x < base_x else pal["grass"][5])
            elif y - y0 == 2 and rng.random() < 0.7:
                for x in range(int(base_x - half * 0.9), int(base_x - half * 0.2)):
                    c.put(x, y, pal["grass"][5])
    c.outline(pal["outline"])
    return c, (base_x, base_y)
