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

    sky = terrain.get("style") in ("sky", "spires", "rift")
    island = None
    if sky:
        island = _island_mask(w, h, int(terrain.get("edge_margin", 64)), seed)
        _paint_sky(img, island, pal, seed)
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
    if not len(water_points):
        pass
    elif not night:
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
    if island is not None:
        free &= ndimage.binary_erosion(island, iterations=6)
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


def _island_mask(w: int, h: int, margin: int, seed: int) -> np.ndarray:
    """Rounded island shape with a wobbly coastline."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    nx = (xs - w / 2) / (w / 2 - margin)
    ny = (ys - h / 2) / (h / 2 - margin)
    wobble = (fbm(w, h, 40.0, seed + 77, 2) - 0.5) * 0.18
    return np.abs(nx) ** 6 + np.abs(ny) ** 6 + wobble <= 1.0


def _paint_sky(img: np.ndarray, island: np.ndarray, pal, seed: int) -> None:
    """Sky and clouds outside the island, a rocky cliff under its south rim."""
    h, w = island.shape
    sky, cloud, stone = pal["sky"], pal["cloud"], pal["stone"]
    rows = np.clip((np.arange(h) / h * len(sky)).astype(int), 0, len(sky) - 1)
    outside = ~island
    for y in range(h):
        img[y][outside[y]] = sky[rows[y]]
    puffs = fbm(w, h, 26.0, seed + 91, 3)
    img[outside & (puffs > 0.58)] = cloud[3]
    img[outside & (puffs > 0.66)] = cloud[5]
    # Cliff: pixels just below the island edge show the rock it stands on.
    cliff = np.zeros_like(island)
    for k in range(1, 14):
        cliff |= np.roll(island, k, 0) & outside
    depth = np.zeros((h, w), dtype=int)
    for k in range(1, 14):
        depth[np.roll(island, k, 0) & outside & (depth == 0)] = k
    img[cliff] = np.array(stone)[np.clip(4 - depth[cliff] // 3, 0, 5)]
    edge = island & ~ndimage.binary_erosion(island, iterations=2)
    img[edge] = pal["grass"][5]


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


def render_crypt(terrain: dict, pal: dict, seed: int) -> Canvas:
    """Dungeon floor plan: flagstone rooms and corridors ("rooms" rectangles)
    inside dark brick walls, with a lit lip along the wall tops."""
    w, h = terrain["size"]
    rng = random.Random(seed)
    floor = np.zeros((h, w), dtype=bool)
    for x, y, rw, rh in terrain.get("rooms", []):
        floor[y:y + rh, x:x + rw] = True
    img = np.zeros((h, w, 4), dtype=np.uint8)
    stone, dirt = pal["stone"], pal["dirt"]
    # Walls: brick courses.
    ys, xs = np.mgrid[0:h, 0:w]
    course = (ys // 8) % 2
    mortar = (ys % 8 == 0) | (((xs + course * 8) % 16) == 0)
    img[:] = stone[1]
    img[mortar] = stone[0]
    # Floor: 16px flagstones with noise.
    n = fbm(w, h, 18.0, seed, 2)
    tile_edge = ((xs + (ys // 16) % 2 * 8) % 16 == 0) | (ys % 16 == 0)
    shade = np.digitize(n, [0.42, 0.6]) + 2
    lut = np.array(dirt)
    img[floor] = lut[shade][floor]
    img[floor & tile_edge] = lut[1]
    # Wall faces just above the floor (front of the wall, 12 px tall).
    face = np.zeros_like(floor)
    for k in range(1, 13):
        face |= np.roll(floor, -k, 0) & ~floor
    img[face] = stone[3]
    img[face & mortar] = stone[2]
    top = face & ~np.roll(face, 1, 0)
    img[top] = stone[4]
    # Floor shadow under walls.
    under = floor & np.roll(~floor, 1, 0)
    img[under] = lut[1]
    # Lava pools (magma dungeon): bright molten centre, crust, glowing rim.
    lava = np.zeros_like(floor)
    for pond in terrain.get("ponds", []):
        if "circle" in pond:
            cx, cy, r = pond["circle"]
            lava |= (xs - cx) ** 2 + ((ys - cy) * 1.0) ** 2 <= r * r
        elif "rect" in pond:
            rx, ry, rw, rh = pond["rect"]
            lava |= (xs >= rx) & (xs < rx + rw) & (ys >= ry) & (ys < ry + rh)
    if lava.any():
        from scipy import ndimage as _nd
        water = np.array(pal["water"])
        heat = fbm(w, h, 10.0, seed + 5, 3)
        depth = _nd.distance_transform_edt(lava)
        level = np.clip((heat * 3 + np.minimum(depth, 12) / 6).astype(int), 0, len(water) - 1)
        img[lava] = water[level][lava]
        crust = lava & (heat < 0.35) & (depth > 4)
        img[crust] = water[0]
        rim = _nd.binary_dilation(lava, iterations=2) & ~lava
        img[rim & floor] = pal["glow"][0]
    img[:, :, 3] = 255
    canvas = Canvas(w, h)
    canvas.px = img
    # Scattered rubble and moss.
    for _ in range(int(w * h / 3000)):
        x, y = rng.randrange(w), rng.randrange(h)
        if floor[y, x]:
            canvas.put(x, y, pal["moss"][rng.randrange(4)] if rng.random() < 0.5 else stone[4])
    return canvas


def crypt_blockers(terrain: dict, cell: int = 16) -> list:
    """Collision for everything that is not floor: row runs of wall cells."""
    w, h = terrain["size"]
    floor = np.zeros((h // cell, w // cell), dtype=bool)
    for x, y, rw, rh in terrain.get("rooms", []):
        floor[y // cell:(y + rh) // cell, x // cell:(x + rw) // cell] = True
    result = []
    for row in range(floor.shape[0]):
        col = 0
        while col < floor.shape[1]:
            if floor[row, col]:
                col += 1
                continue
            start = col
            while col < floor.shape[1] and not floor[row, col]:
                col += 1
            x0, x1 = start * cell, col * cell
            result.append({"center": [(x0 + x1) / 2, row * cell + cell / 2], "size": [x1 - x0, cell]})
    return result
