"""HD region ground (2 texture pixels per world pixel), painted from the
asset pack: synthesized ground (grass, moss, sand, snow, ash, cave stone),
earthy trails with pebbles, water / lava / bog / glowing pools, cobbled
plazas, dungeon rooms with brick walls, scattered decals, soft shadows
under trees and houses, plank walkways at the rim exits.

Geometry is the same "terrain" data the game uses (data/regions.json);
the look of each biome comes from hd/styles.py."""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image
from scipy import ndimage

import pixel
from hd import pack
from hd.styles import STYLE

K = pack.K


def _up(a: np.ndarray, w: int, h: int) -> np.ndarray:
    """World-resolution field → texture resolution (smooth)."""
    return np.array(Image.fromarray(a.astype(np.float32), mode="F").resize((w, h), Image.BILINEAR))


def _noise(w: int, h: int, cell: float, seed: int, octaves: int = 3) -> np.ndarray:
    sw, sh = max(2, w // 4), max(2, h // 4)
    return _up(pixel.fbm(sw, sh, cell / 4, seed, octaves).astype(np.float32), w, h)


def _smooth(points, iterations: int = 3):
    for _ in range(iterations):
        result = [points[0]]
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            result.append((ax * 0.75 + bx * 0.25, ay * 0.75 + by * 0.25))
            result.append((ax * 0.25 + bx * 0.75, ay * 0.25 + by * 0.75))
        result.append(points[-1])
        points = result
    return points


def _trail_distance(terrain: dict, w: int, h: int) -> np.ndarray:
    sw, sh = w // K, h // K
    best = np.full((sh, sw), 1e4, dtype=np.float32)
    for points in terrain.get("trails", []):
        best = np.minimum(best, pixel.polyline_distance(sw, sh, _smooth([tuple(p) for p in points])))
    return _up(best, w, h)


def _pond_field(terrain: dict, w: int, h: int, seed: int) -> np.ndarray:
    """>0 inside the pools (depth in world px), <0 outside."""
    sw, sh = w // K, h // K
    mask = np.zeros((sh, sw), dtype=bool)
    ys, xs = np.mgrid[0:sh, 0:sw].astype(np.float32) + 0.5
    wobble = pixel.fbm(sw, sh, 14.0, seed, 2) - 0.5
    for pond in terrain.get("ponds", []):
        if "rect" in pond:
            x, y, rw, rh = pond["rect"]
            cx, cy, ax, ay = x + rw / 2, y + rh / 2, rw / 2, rh / 2
            d = np.abs((xs - cx) / ax) ** 3.2 + np.abs((ys - cy) / ay) ** 3.2
            mask |= d + wobble * 0.5 <= 1.0
        else:
            cx, cy, r = pond["circle"]
            d = np.hypot(xs - cx, (ys - cy) * 1.08) / r
            mask |= d + wobble * 0.25 <= 1.0
    if not mask.any():
        return np.zeros((h, w), dtype=np.float32) - 100.0
    inside = ndimage.distance_transform_edt(mask)
    outside = ndimage.distance_transform_edt(~mask)
    return _up((inside - outside).astype(np.float32), w, h)


def _plaza_field(terrain: dict, w: int, h: int) -> np.ndarray:
    sw, sh = w // K, h // K
    ys, xs = np.mgrid[0:sh, 0:sw].astype(np.float32) + 0.5
    field = np.full((sh, sw), -1e4, dtype=np.float32)
    for plaza in terrain.get("plazas", []):
        if "circle" in plaza:
            cx, cy, r = plaza["circle"]
            f = r - np.sqrt((xs - cx) ** 2 + ((ys - cy) * 1.15) ** 2)
        else:
            rx, ry, rw, rh = plaza["rect"]
            f = np.minimum(np.minimum(xs - rx, rx + rw - xs), np.minimum(ys - ry, ry + rh - ys))
        field = np.maximum(field, f)
    return _up(field, w, h)


def _cobbles(w: int, h: int, stone: list, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w]
    row_h, col_w = 11, 15
    row = ys // row_h
    shift = (row % 2) * (col_w // 2)
    col = (xs + shift) // col_w
    lx = (xs + shift) % col_w - col_w / 2 + 0.5
    ly = ys % row_h - row_h / 2 + 0.5
    r = np.sqrt((lx / (col_w / 2 - 1)) ** 4 + (ly / (row_h / 2 - 1)) ** 4)
    tone = rng.random((h // row_h + 2, w // col_w + 3))[row, col]
    base = np.array(stone[3]) * (0.86 + tone[..., None] * 0.22)
    light = np.clip(-ly / row_h - lx / col_w * 0.5, -1, 1)[..., None]
    out = base * (1.0 + light * 0.22)
    out = np.where((r > 0.92)[..., None], np.array(stone[1]), out)
    return np.clip(out / 255.0, 0, 1)


def _palette_noise(w: int, h: int, pal: list, seed: int) -> np.ndarray:
    pal = np.array(pal, dtype=np.float32) / 255.0
    n = _noise(w, h, 40.0, seed, 3) * 0.7 + _noise(w, h, 6.0, seed + 1, 2) * 0.3
    fine = np.random.default_rng(seed).random((h, w)).astype(np.float32)
    level = np.clip(n * 1.5 - 0.25 + (fine - 0.5) * 0.18, 0, 0.999) * (len(pal) - 1)
    lo = np.floor(level).astype(int)
    t = (level - lo)[..., None]
    return pal[lo] * (1 - t) + pal[np.minimum(lo + 1, len(pal) - 1)] * t


def _synth(spec: list, w: int, h: int, seed: int, patch: int, step: int) -> np.ndarray:
    sources = [(pack.crop(rel, box), weight) for rel, box, weight in spec]
    smallest = min(min(s.shape[0], s.shape[1]) for s, _ in sources)
    patch = min(patch, smallest - 2)
    step = min(step, max(8, int(patch * 0.62)))
    return pack.synthesize(sources, w, h, seed, patch=patch, step=step)


def _paste(canvas: np.ndarray, sprite: np.ndarray, x: int, y: int, opacity: float = 1.0) -> None:
    h, w = canvas.shape[:2]
    sh, sw = sprite.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(w, x + sw), min(h, y + sh)
    if x1 <= x0 or y1 <= y0:
        return
    s = sprite[y0 - y:y1 - y, x0 - x:x1 - x]
    a = s[:, :, 3:4] * opacity
    region = canvas[y0:y1, x0:x1]
    region[:] = region * (1 - a) + s[:, :, :3] * a


def _sprite(rel: str, size: float, tint=None) -> np.ndarray:
    img = pack.content(pack.image(rel))
    scale = size * K / img.width
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    if tint is not None:
        arr[:, :, :3] *= np.array(tint)
    return arr


def _shadow(canvas: np.ndarray, cx: float, cy: float, rx: float, ry: float, strength: float) -> None:
    h, w = canvas.shape[:2]
    x0, x1 = int(max(0, cx - rx * 1.4)), int(min(w, cx + rx * 1.4))
    y0, y1 = int(max(0, cy - ry * 1.4)), int(min(h, cy + ry * 1.4))
    if x1 <= x0 or y1 <= y0:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    a = np.clip(1.0 - d, 0, 1) ** 1.5 * strength
    canvas[y0:y1, x0:x1] *= (1.0 - a)[..., None]


def _pebbles(ground: np.ndarray, edge: np.ndarray, stone_pal: list, seed: int) -> None:
    rng = np.random.default_rng(seed)
    h, w = ground.shape[:2]
    stone = np.array(stone_pal, dtype=np.float32) / 255.0
    count = int((edge > 0).sum() / 260)
    xs = rng.integers(8, w - 8, count * 3)
    ys = rng.integers(8, h - 8, count * 3)
    placed = 0
    for x, y in zip(xs, ys):
        e = edge[y, x]
        if e <= 1.0 or rng.random() > 0.35 + 0.65 * math.exp(-max(0.0, e - 2.0) / 4.0):
            continue
        rx, ry = rng.uniform(2.4, 5.2), rng.uniform(1.8, 3.4)
        tone = stone[rng.integers(2, 5)]
        x0, x1, y0, y1 = int(x - rx - 1), int(x + rx + 2), int(y - ry - 1), int(y + ry + 3)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        d = ((xx - x) / rx) ** 2 + ((yy - y) / ry) ** 2
        body = d <= 1.0
        under = (((xx - x) / rx) ** 2 + ((yy - y - 1.2) / ry) ** 2 <= 1.0) & ~body
        top = body & (yy < y - ry * 0.25)
        region = ground[y0:y1, x0:x1]
        region[under] *= 0.7
        region[body] = tone
        region[top] = np.minimum(1.0, tone * 1.22)
        placed += 1
        if placed >= count:
            break


def _walkways(ground: np.ndarray, gates: list, ww: int, wh: int) -> np.ndarray:
    h, w = ground.shape[:2]
    mask = np.zeros((h, w), np.float32)
    deck = pack.content(pack.image("new:hd/redrawn/islands/rope_bridge.png"))
    mid = deck.crop((int(deck.width * 0.3), 0, int(deck.width * 0.7), deck.height))
    for gx, gy in gates:
        edges = {"left": gx, "right": ww - gx, "top": gy, "bottom": wh - gy}
        side = min(edges, key=edges.get)
        if edges[side] > 120:
            continue
        length = edges[side] + 4
        if side in ("left", "right"):
            img = mid.resize((max(1, int(length * K)), int(30 * K)), Image.LANCZOS)
            x = 0 if side == "left" else int((gx - 4) * K)
            y = int((gy - 15) * K)
        else:
            img = mid.rotate(90, expand=True).resize((int(30 * K), max(1, int(length * K))), Image.LANCZOS)
            x = int((gx - 15) * K)
            y = 0 if side == "top" else int((gy - 4) * K)
        arr = np.asarray(img, np.float32) / 255.0
        _shadow(ground, x + arr.shape[1] / 2, y + arr.shape[0] / 2 + 6, arr.shape[1] * 0.55, arr.shape[0] * 0.55, 0.25)
        _paste(ground, arr, x, y)
        sh, sw = arr.shape[:2]
        mask[max(0, y):y + sh, max(0, x):x + sw] = 1.0
    return mask


def _liquid(ground: np.ndarray, water: np.ndarray, cfg: dict, w: int, h: int, seed: int) -> None:
    kind = cfg.get("liquid", "water")
    wp = np.array(cfg["water"], dtype=np.float32) / 255.0  # shallow → deep
    depth = np.clip(water / 18.0, 0, 1)
    inside = np.clip(water * K * 0.6, 0, 1)[..., None]
    if kind == "lava":
        # Painted molten rock from the pack, hotter towards the middle.
        col = pack.synthesize([(pack.crop("@2", (226, 874, 278, 924)), 1.0)], w, h, seed + 19, patch=40, step=24)
        heat = _noise(w, h, 12.0, seed + 21, 2)
        col = col * (0.85 + 0.35 * heat[..., None]) * (0.8 + 0.3 * depth[..., None])
        col = np.minimum(1.0, col)
        ground[:] = ground * (1 - inside) + col * inside
        rim = np.clip(1.0 - np.abs(water - 0.5) / 2.0, 0, 1)
        ground[:] = ground * (1 - rim[..., None] * 0.7) + np.array([0.2, 0.08, 0.05]) * rim[..., None] * 0.7
        glow = np.clip(1.0 + water / 14.0, 0, 1) * (water < 0)
        ground[:] = np.minimum(1.0, ground + np.array([0.55, 0.2, 0.02]) * (glow ** 2)[..., None] * 0.5)
        return
    col = wp[0] * (1 - depth[..., None]) + wp[1] * depth[..., None]
    waves = _noise(w, h, 10.0, seed + 19, 2)
    streak = np.clip(1.0 - np.abs(np.sin((np.arange(h)[:, None] / (5.0 * K)) + waves * 9.0)) * 6.0, 0, 1)
    shine = cfg.get("water_shine", 0.10 if kind != "murk" else 0.05)
    col = col + (streak * shine * (0.3 + depth))[..., None]
    foam_c = np.array([0.86, 0.96, 1.0]) if kind != "murk" else np.array([0.5, 0.56, 0.42])
    foam = np.clip(1.0 - np.abs(water - 3.0) / 1.2, 0, 1) * cfg.get("water_foam", 0.55 if kind != "murk" else 0.3)
    col = col * (1 - foam[..., None]) + foam_c * foam[..., None]
    if kind == "glow":
        col = col + np.array([0.1, 0.35, 0.45]) * (np.clip(depth * 1.5, 0, 1) ** 2)[..., None]
    ground[:] = ground * (1 - inside) + col * inside
    bank = np.clip(1.0 - np.abs(water - 1.2) / 1.4, 0, 1)
    darkbank = np.array(cfg["dirt"][0], dtype=np.float32) / 255.0
    bank_strength = cfg.get("water_bank", 0.65)
    ground[:] = ground * (1 - bank[..., None] * bank_strength) + darkbank * bank[..., None] * bank_strength
    shore = np.clip(1.0 - np.abs(water + 2.5) / 2.5, 0, 1) * (water < 0)
    ground *= (1.0 - shore * 0.18)[..., None]
    if kind == "glow":
        halo = np.clip(1.0 + water / 12.0, 0, 1) * (water < 0)
        ground[:] = np.minimum(1.0, ground + np.array([0.1, 0.35, 0.4]) * (halo ** 2)[..., None] * 0.35)


def _float_decals(ground: np.ndarray, water: np.ndarray, cfg: dict, rng: random.Random, ww: int, wh: int) -> None:
    """Lily pads and the like on the water surface."""
    for rel, box, size, count in cfg.get("water_decals", []):
        piece = pack.crop(rel, box)
        img = Image.fromarray((piece * 255).astype(np.uint8), "RGBA")
        h, w = ground.shape[:2]
        target = int(count * ww * wh / (1600 * 1080))
        for _ in range(target * 6):
            if target <= 0:
                break
            s = size * rng.uniform(0.7, 1.2)
            sp = np.asarray(img.resize((int(s * K), int(s * K)), Image.LANCZOS), np.float32) / 255.0
            yy, xx = np.mgrid[0:sp.shape[0], 0:sp.shape[1]]
            r = np.hypot(xx - sp.shape[1] / 2, yy - sp.shape[0] / 2) / (sp.shape[0] / 2)
            sp[:, :, 3] *= np.clip((1 - r) * 2.5, 0, 1)
            x, y = rng.randint(0, w - sp.shape[1]), rng.randint(0, h - sp.shape[0])
            if water[y + sp.shape[0] // 2, x + sp.shape[1] // 2] < 6:
                continue
            _paste(ground, sp, x, y, 0.9)
            target -= 1



def _shore_decals(ground: np.ndarray, water: np.ndarray, path: np.ndarray, cfg: dict, seed: int) -> None:
    """Approved stones and ferns break up the bank; no continuous glowing ring."""
    rng = random.Random(seed + 501)
    h, w = water.shape
    for rel, size, count in cfg.get("shore_decals", []):
        sprite = _sprite(rel, size)
        sh, sw = sprite.shape[:2]
        placed = 0
        for _ in range(count * 500):
            if placed >= count:
                break
            x, y = rng.randint(0, w - sw), rng.randint(0, h - sh)
            cx, cy = x + sw // 2, y + sh // 2
            if not (-14.0 < water[cy, cx] < -4.0) or path[cy, cx] > 0.1:
                continue
            _paste(ground, sprite, x, y)
            placed += 1

def _rooms(terrain: dict, w: int, h: int) -> np.ndarray:
    sw, sh = w // K, h // K
    floor = np.zeros((sh, sw), bool)
    for x, y, rw, rh in terrain.get("rooms", []):
        floor[y:y + rh, x:x + rw] = True
    return floor


def render(region_id: str, terrain: dict, seed: int, footprints: list, gates: list | None = None) -> Image.Image:
    """footprints: [(x, y, half_width)] world positions of trees/houses for shadows."""
    cfg = STYLE[terrain.get("art_style", terrain.get("style", "day"))]
    ww, wh = terrain["size"]
    w, h = ww * K, wh * K
    rng = random.Random(seed)

    # 1. Base ground, recoloured, with overlay patches (snow, moss, sand...).
    ground = _synth(cfg["grass"], w, h, seed, cfg.get("patch", 64), cfg.get("step", 40))
    if cfg.get("recolor"):
        ground *= np.array(cfg["recolor"])
    for index, layer in enumerate(cfg.get("overlays", [])):
        tex = _synth(layer["sources"], w, h, seed + 60 + index, layer.get("patch", 40), layer.get("step", 26))
        if layer.get("recolor"):
            tex *= np.array(layer["recolor"])
        n = _noise(w, h, layer.get("cell", 140.0), seed + 70 + index, 3)
        n += (_noise(w, h, 3.0, seed + 80 + index, 1) - 0.5) * 0.08
        cover = layer.get("cover", 0.5)
        m = np.clip((n - (1.0 - cover)) * 14.0, 0, 1)[..., None]
        ground = ground * (1 - m) + tex * m
    tint = _noise(w, h, 180.0, seed + 5, 3)
    shade = cfg.get("shade", (0.80, 1.06))
    ground *= (shade[0] + (shade[1] - shade[0]) * tint)[..., None]
    warm = np.array(cfg.get("warm", (1.04, 1.02, 0.86)))
    cool = np.array(cfg.get("cool", (0.86, 0.98, 1.02)))
    ground *= (cool + (warm - cool) * tint[..., None])

    path = np.zeros((h, w), np.float32)

    # 1b. Dungeons: floor rooms inside brick walls.
    if cfg.get("crypt"):
        floor_small = _rooms(terrain, w, h)
        walls = _synth(cfg["walls"], w, h, seed + 7, 40, 24)
        floor = _up(floor_small.astype(np.float32), w, h) > 0.5
        face = np.zeros_like(floor)
        for k in range(1, 12 * K + 1):
            face |= np.roll(floor, -k, 0) & ~floor
        top_edge = face & ~np.roll(face, 1, 0)
        dark = cfg.get("wall_shade", 0.42)
        out = walls * dark
        out[face] = walls[face] * min(0.9, dark * 2.2)
        lip = np.zeros_like(floor)
        for k in range(0, 3):
            lip |= np.roll(top_edge, k, 0)
        out[lip] = np.minimum(1.0, walls[lip] * min(1.25, dark * 3.0))
        dist = ndimage.distance_transform_edt(floor)
        under = np.clip(1.0 - dist / (6 * K), 0, 1)[..., None]
        floor_col = ground * (1 - under * 0.45)
        ground = np.where(floor[..., None], floor_col, out)
        path = np.maximum(path, (~floor).astype(np.float32))

    # 2. Trails.
    dist = _trail_distance(terrain, w, h)
    radius = cfg.get("trail_radius", 12.5) + (_noise(w, h, 18.0, seed + 3, 2) - 0.5) * 5.0
    fringe = (_noise(w, h, 2.2, seed + 9, 1) - 0.5) * 3.2
    edge = radius + fringe - dist
    trail = np.clip(edge * 1.2, 0, 1)
    if trail.any():
        dirt = _palette_noise(w, h, cfg["dirt"], seed + 11)
        if cfg.get("dirt_tile"):
            rel, box = cfg["dirt_tile"]
            sample = pack.synthesize([(pack.crop(rel, box), 1.0)], w, h, seed + 15, patch=28, step=16)
            lum = sample.mean(axis=2, keepdims=True)
            dirt *= 0.7 + 0.6 * (lum / max(1e-3, float(lum.mean())) - 1.0) + 0.3
        dirt *= (0.86 + 0.18 * np.clip((edge - 2.0) / 8.0, 0, 1))[..., None]
        lip = np.clip(1.0 - np.abs(edge - 1.2) / 2.2, 0, 1) * 0.35
        dirt *= (1.0 - lip)[..., None]
        ground = ground * (1 - trail[..., None]) + dirt * trail[..., None]
        ground *= (1.0 - np.clip(1.0 - np.abs(edge - 3.0) / 2.0, 0, 1) * 0.12 * trail)[..., None]
        _pebbles(ground, edge, cfg["stone"], seed + 12)
        path = np.maximum(path, trail)

    # 3. Plazas.
    plaza = _plaza_field(terrain, w, h)
    if (plaza > 0).any():
        cob = _cobbles(w, h, cfg["stone"], seed + 13)
        pm = np.clip(plaza * K * 0.5, 0, 1)
        rim = np.clip(1.0 - np.abs(plaza - 1.5) / 1.5, 0, 1)
        cob *= (1.0 - rim * 0.45)[..., None]
        ground = ground * (1 - pm[..., None]) + cob * pm[..., None]
        path = np.maximum(path, pm)

    # 4. Pools.
    water = _pond_field(terrain, w, h, seed + 17)
    if (water > 0).any():
        _liquid(ground, water, cfg, w, h, seed)
        _float_decals(ground, water, cfg, rng, ww, wh)
        path = np.maximum(path, (water > -3).astype(np.float32))

    # 4b. Caves: the rock wall closing in at the map edges.
    if cfg.get("cave_rim"):
        ys, xs = np.mgrid[0:h, 0:w]
        border = np.minimum(np.minimum(xs, w - 1 - xs), np.minimum(ys, h - 1 - ys)) / K
        reach = 26 + _noise(w, h, 40.0, seed + 91, 3) * 34
        wall = border < reach
        rock = _synth(cfg["walls"], w, h, seed + 93, 40, 24)
        shade = np.clip(border / reach, 0, 1)[..., None]
        ground = np.where(wall[..., None], rock * (0.35 + 0.45 * shade), ground)
        ground[np.abs(border - reach) < 1.6] *= 0.5
        path = np.maximum(path, wall.astype(np.float32))

    if gates and cfg.get("walkways", True):
        path = np.maximum(path, _walkways(ground, gates, ww, wh))

    # 5. Shadows of trees and houses.
    for x, y, half in footprints:
        _shadow(ground, x * K, (y + 2) * K, half * K * 1.05, half * K * 0.42, cfg.get("shadow", 0.42))

    _shore_decals(ground, water, path, cfg, seed)

    # 6. Decals on open ground.
    free = path < 0.05
    meadow = _noise(w, h, 140.0, seed + 23, 2)
    for rel, size, count in cfg.get("decals", []):
        sprite = _sprite(rel, size, cfg.get("decal_tint"))
        sh, sw = sprite.shape[:2]
        placed = 0
        tries = 0
        target = int(count * ww * wh / (1920 * 1280))
        while placed < target and tries < target * 10:
            tries += 1
            x, y = rng.randint(0, w - sw), rng.randint(0, h - sh)
            if not free[min(h - 1, y + sh - 2), x + sw // 2] or not free[y + sh // 2, x + sw // 2]:
                continue
            if rng.random() > (meadow[y, x] - 0.35) * 2.6:
                continue
            if any(abs(x / K - fx) < fh and abs(y / K - fy) < fh * 0.6 for fx, fy, fh in footprints):
                continue
            _paste(ground, sprite, x, y)
            placed += 1

    out = (np.clip(ground, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(out, "RGB")
