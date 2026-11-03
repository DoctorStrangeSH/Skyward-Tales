"""Pre-rendered region ground: textured grass, dirt trails, ponds, flowers."""
from __future__ import annotations

import math
import random

import numpy as np
from scipy import ndimage

from pixel import Canvas, bayer, fbm, polyline_distance


def _pond_mask(w: int, h: int, pond: dict, seed: int) -> np.ndarray:
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    wobble = fbm(w, h, 14.0, seed, 2) - 0.5
    if "rect" in pond:
        x, y, rw, rh = pond["rect"]
        cx, cy, ax, ay = x + rw / 2, y + rh / 2, rw / 2, rh / 2
        # Superellipse keeps the collision rectangle mostly filled with water.
        d = np.abs((xs - cx) / ax) ** 3.2 + np.abs((ys - cy) / ay) ** 3.2
        return d + wobble * 0.5 <= 1.0
    cx, cy, r = pond["circle"]
    d = np.hypot(xs - cx, (ys - cy) * 1.08) / r
    return d + wobble * 0.25 <= 1.0


def render_ground(terrain: dict, pal: dict, seed: int) -> Canvas:
    w, h = terrain["size"]
    night = terrain.get("style") in ("night", "cave")
    cave = terrain.get("style") == "cave"
    rng = random.Random(seed)
    grass, dirt, water = pal["grass"], pal["dirt"], pal["water"]

    # 1. Grass: large soft patches, posterised into clean pixel clusters.
    n = fbm(w, h, 46.0, seed, 3) * 0.8 + fbm(w, h, 7.0, seed + 7, 2) * 0.2
    n = n + (bayer(w, h) - 0.5) * 0.035
    level = np.digitize(n, [0.40, 0.66]) + 2  # 2..4, mostly mid green
    img = np.zeros((h, w, 4), dtype=np.uint8)
    lut = np.array(grass)
    img[:] = lut[level]
    # Lighter patch tops catch light, bottoms get a shadow lip.
    up = np.roll(level, 1, 0)
    img[(level > up)] = lut[np.clip(level + 1, 0, 6)][(level > up)]
    down = np.roll(level, -1, 0)
    img[(level > down)] = lut[np.clip(level - 1, 0, 6)][(level > down)]

    # 2. Trails.
    path = np.zeros((h, w), dtype=bool)
    rim = np.zeros((h, w), dtype=bool)
    edge_noise = fbm(w, h, 9.0, seed + 3, 2)
    dirt_noise = fbm(w, h, 5.0, seed + 4, 2)
    for points in terrain.get("trails", []):
        d = polyline_distance(w, h, _smooth([tuple(p) for p in points]))
        radius = 10.0 + (edge_noise - 0.5) * 4.0
        path |= d < radius
        rim |= (d >= radius) & (d < radius + 1.3)
    inner = ndimage.binary_erosion(path, iterations=2)
    dlevel = np.digitize(dirt_noise, [0.35, 0.62]) + 2  # 2..4
    dlut = np.array(dirt)
    img[path] = dlut[dlevel][path]
    border = path & ~inner
    top_edge = border & ~np.roll(path, 1, 0)
    img[border] = dirt[1]
    img[top_edge] = dirt[0]
    img[rim] = grass[1]

    # 3. Ponds.
    water_mask = np.zeros((h, w), dtype=bool)
    for index, pond in enumerate(terrain.get("ponds", [])):
        water_mask |= _pond_mask(w, h, pond, seed + 50 + index)
    if water_mask.any():
        depth = ndimage.distance_transform_edt(water_mask)
        wlut = np.array(water)
        if night:
            # Magic pool: glows brighter towards the centre.
            wl = np.digitize(depth, [2, 5, 11, 20])
            wl = np.array([1, 2, 3, 3, 4])[wl]
        else:
            dithered = depth + (bayer(w, h) - 0.5) * 3.0
            wl = np.digitize(dithered, [2.5, 6, 13, 24])
            wl = np.array([3, 2, 2, 1, 0])[wl]
        img[water_mask] = wlut[wl][water_mask]
        # Northern bank: the ground edge is seen from above as a short wall.
        land = ~water_mask
        bank = np.zeros_like(water_mask)
        for k in range(1, 4):
            bank |= water_mask & np.roll(land, k, 0)
        img[bank] = dirt[1]
        bank_top = water_mask & np.roll(land, 1, 0)
        img[bank_top] = dirt[2]
        foam = water_mask & ~bank & np.roll(bank, 1, 0)
        img[foam] = water[5 if night else 4]
        # Shore ring.
        shore = ndimage.binary_dilation(water_mask, iterations=2) & land & ~path
        img[shore] = dirt[3] if not night else dirt[2]
        outer = ndimage.binary_dilation(water_mask, iterations=3) & land & ~shore & ~path
        img[outer] = grass[1]

    canvas = Canvas(w, h)
    canvas.px = img

    # 4. Details: highlight streaks on water, lily pads, pebbles, tufts, flowers.
    water_depth = ndimage.distance_transform_edt(water_mask) if water_mask.any() else np.zeros((h, w))
    water_points = np.argwhere(water_mask & (water_depth > 4))
    for _ in range(len(water_points) // 260):
        y, x = water_points[rng.randrange(len(water_points))]
        length = rng.randint(2, 5)
        for i in range(length):
            if water_mask[y, min(w - 1, x + i)]:
                canvas.put(x + i, y, water[4] if i else water[5])
    if not night:
        for _ in range(len(water_points) // 1800 + 2):
            y, x = water_points[rng.randrange(len(water_points))]
            if water_depth[y, x] < 7:
                continue
            canvas.ellipse(x, y, 4, 2.6, pal["leaf"][4])
            canvas.hline(x - 3, x + 3, y + 2, pal["leaf"][2])
            canvas.put(x + 2, y - 1, water[1])
            canvas.put(x + 3, y - 1, water[1])
            if rng.random() < 0.6:
                canvas.put(x - 1, y - 1, pal["flowers"][2][0])
                canvas.put(x, y - 1, pal["flowers"][0][0])
    else:
        glow = pal["glow"]
        for _ in range(len(water_points) // 120):
            y, x = water_points[rng.randrange(len(water_points))]
            canvas.put(x, y, glow[rng.randrange(3)])

    path_points = np.argwhere(inner)
    for _ in range(len(path_points) // 160):
        y, x = path_points[rng.randrange(len(path_points))]
        canvas.put(x, y, dirt[5])
        canvas.put(x + 1, y, dirt[4])
        canvas.put(x, y + 1, dirt[1])
        canvas.put(x + 1, y + 1, dirt[1])

    free = ~(path | water_mask | rim)
    free = ndimage.binary_erosion(free, iterations=3)
    tuft_density = fbm(w, h, 30.0, seed + 9, 2)
    for _ in range(int(w * h / 120)):
        x, y = rng.randrange(w), rng.randrange(h)
        if not free[y, x] or tuft_density[y, x] < rng.random() * 0.9:
            continue
        if cave:
            _crack(canvas, x, y, grass, rng)
        else:
            _tuft(canvas, x, y, grass, rng)
    flower_sets = pal["flowers"]
    for _ in range(int(w * h / 3500)):
        cx, cy = rng.randrange(w), rng.randrange(h)
        colors = flower_sets[rng.randrange(len(flower_sets))]
        for _ in range(rng.randint(3, 7)):
            x, y = cx + rng.randint(-6, 6), cy + rng.randint(-4, 4)
            if 0 <= x < w - 1 and 0 <= y < h - 1 and free[y, x]:
                canvas.put(x, y + 1, grass[1])
                canvas.put(x, y, colors[0])
                if rng.random() < 0.4:
                    canvas.put(x + 1, y, colors[1])
    if night:
        # Glowing mushrooms scattered in clusters.
        glow = pal["glow"]
        for _ in range(int(w * h / 9000)):
            cx, cy = rng.randrange(w), rng.randrange(h)
            for _ in range(rng.randint(2, 4)):
                x, y = cx + rng.randint(-5, 5), cy + rng.randint(-3, 3)
                if 0 <= x < w - 2 and 1 <= y < h - 2 and free[y, x]:
                    canvas.put(x, y, glow[1])
                    canvas.put(x + 1, y, glow[0])
                    canvas.put(x - 1, y, glow[0])
                    canvas.put(x, y - 1, glow[2])
                    canvas.put(x, y + 1, pal["dirt"][4])
    return canvas


def _smooth(points: list[tuple[float, float]], iterations: int = 3) -> list[tuple[float, float]]:
    """Chaikin corner cutting: turns a polyline into a soft winding road."""
    for _ in range(iterations):
        result = [points[0]]
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            result.append((ax * 0.75 + bx * 0.25, ay * 0.75 + by * 0.25))
            result.append((ax * 0.25 + bx * 0.75, ay * 0.25 + by * 0.75))
        result.append(points[-1])
        points = result
    return points


def _crack(canvas: Canvas, x: int, y: int, floor, rng: random.Random) -> None:
    """Cave floor detail: hairline cracks and small pebbles instead of grass."""
    if rng.random() < 0.5:
        for i in range(rng.randint(2, 5)):
            canvas.put(x + i, y + (i // 2) * (1 if rng.random() < 0.5 else -1), floor[0])
    else:
        canvas.put(x, y, floor[5])
        canvas.put(x + 1, y, floor[4])
        canvas.put(x, y + 1, floor[1])


def _tuft(canvas: Canvas, x: int, y: int, grass, rng: random.Random) -> None:
    """A small clump of blades: dark base, mid stems, bright tips."""
    blades = rng.choice([(-1, 0, 1), (-2, 0, 2), (-1, 1), (0,), (-2, -1, 1, 2)])
    for offset in blades:
        height = rng.randint(2, 4) - (1 if abs(offset) == 2 else 0)
        lean = 1 if offset > 0 and rng.random() < 0.4 else (-1 if offset < 0 and rng.random() < 0.4 else 0)
        for i in range(height):
            px = x + offset + (lean if i == height - 1 else 0)
            color = grass[6] if i == height - 1 else (grass[5] if i > 0 else grass[4])
            canvas.put(px, y - i, color)
    canvas.put(x, y + 1, grass[1])
