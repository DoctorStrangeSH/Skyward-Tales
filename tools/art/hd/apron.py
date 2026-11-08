"""HD island edges (2 texture px per world px): the sky around the island
with painted clouds and distant floating islands, the rock cliff under its
south rim and along its sides, a grassy overhang, hanging vines, waterfalls
spilling into the clouds and rope bridges at the exits.

Painted on one canvas spanning the map plus a 160 px margin, then cut into
four strips around the map (top/bottom/left/right). Lands whose island is
smaller than the map (sky islands, "edge_margin") also get an "inner" layer
covering the map outside the island; the game draws it over the ground."""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image

import pixel
from hd import pack

K = pack.K
M = 160  # apron width in world px

FI = "skylands/floating_islands/floating_island_%03d.png"
CLOUDS = "clouds/%s.png"

SKIES = {
    "day": ((96, 156, 222), (198, 226, 248)),
    "night": ((18, 22, 58), (60, 70, 132)),
    "dusk": ((60, 76, 92), (150, 166, 156)),
    "sunset": ((222, 132, 110), (255, 214, 168)),
    "violet": ((34, 16, 56), (118, 70, 150)),
    "ash": ((48, 28, 30), (128, 82, 62)),
    "cold": ((120, 170, 220), (220, 236, 250)),
}
CLOUD_TINT = {"day": (1.0, 1.0, 1.0), "night": (0.42, 0.46, 0.72), "dusk": (0.7, 0.76, 0.74),
              "sunset": (1.0, 0.82, 0.76), "violet": (0.66, 0.5, 0.82), "ash": (0.62, 0.48, 0.44), "cold": (0.96, 0.98, 1.0)}
ROCK = (FI % 7, (22, 50, 104, 92))
GRASS = ("skylands/terrain_tiles/sky_terrain_002.png", (16, 16, 112, 112))
LEAF = [np.array(c, np.float32) / 255.0 for c in ((34, 70, 30), (58, 110, 40), (96, 156, 52), (150, 196, 70))]


def _sprite(rel: str, world_width: float, tint=(1.0, 1.0, 1.0), haze: tuple | None = None) -> np.ndarray:
    img = pack.content(pack.image(rel))
    scale = world_width * K / img.width
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    arr[:, :, :3] *= np.array(tint)
    if haze is not None:
        color, amount = haze
        arr[:, :, :3] = arr[:, :, :3] * (1 - amount) + np.array(color) * amount
    return arr


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.arr = np.zeros(((h + 2 * M) * K, (w + 2 * M) * K, 4), np.float32)

    def px(self, wx: float, wy: float) -> tuple[int, int]:
        return int(round((wx + M) * K)), int(round((wy + M) * K))

    def paste(self, sprite: np.ndarray, wx: float, wy: float, opacity: float = 1.0) -> None:
        x, y = self.px(wx, wy)
        sh, sw = sprite.shape[:2]
        ah, aw = self.arr.shape[:2]
        x0, y0, x1, y1 = max(0, x), max(0, y), min(aw, x + sw), min(ah, y + sh)
        if x1 <= x0 or y1 <= y0:
            return
        s = sprite[y0 - y:y1 - y, x0 - x:x1 - x]
        a = s[:, :, 3:4] * opacity
        region = self.arr[y0:y1, x0:x1]
        region[:, :, :3] = region[:, :, :3] * (1 - a) + s[:, :, :3] * a
        region[:, :, 3:4] = region[:, :, 3:4] + a * (1 - region[:, :, 3:4])


def _vine(arr: np.ndarray, x: float, y: float, length: float, rng: random.Random) -> None:
    h, w = arr.shape[:2]
    sway = rng.uniform(-0.25, 0.25)
    for i in range(int(length)):
        px = int(x + math.sin(i * 0.12 + sway * 9) * 2.0 + sway * i * 0.3)
        py = int(y + i)
        if not (0 <= px < w - 2 and 0 <= py < h):
            break
        arr[py, px:px + 2, :3] = LEAF[1]
        arr[py, px:px + 2, 3] = 1.0
        if i % 7 == 3:
            side = 1 if (i // 7) % 2 else -2
            arr[py:py + 3, max(0, px + side):px + side + 3, :3] = LEAF[2 if rng.random() < 0.6 else 3]
            arr[py:py + 3, max(0, px + side):px + side + 3, 3] = 1.0


def render(region_id: str, terrain: dict, gates: list, seed: int, sky: str = "day",
           island: tuple | None = None, rock_tint=(1.0, 1.0, 1.0), lip_tint=(1.0, 1.0, 1.0),
           falls: int = 3, fall_color=(0.7, 0.88, 1.0), vines: bool = True, lip_sources: list | None = None) -> dict[str, Image.Image]:
    w, h = terrain["size"]
    ix0, iy0, ix1, iy1 = island or (0, 0, w, h)
    rng = random.Random(seed)
    cv = Canvas(w, h)
    arr = cv.arr
    AH, AW = arr.shape[:2]
    top_c, bottom_c = (np.array(c, np.float32) / 255.0 for c in SKIES[sky])
    tint = CLOUD_TINT[sky]

    # 1. Sky gradient.
    rows = np.linspace(0, 1, AH)[:, None]
    arr[:, :, :3] = (top_c * (1 - rows) + bottom_c * rows)[:, None, :]
    arr[:, :, 3] = 1.0

    def off_island(x: float, y: float, pad: float) -> bool:
        return not (ix0 - pad < x < ix1 + pad and iy0 - pad < y < iy1 + pad)

    gate_spots = [tuple(g) for g in gates]

    def near_gate(x: float, y: float, r: float) -> bool:
        return any(math.hypot(x - gx, y - gy) < r for gx, gy in gate_spots)

    # 2. Far islands in the haze, then clouds behind the island.
    haze = (tuple(bottom_c), 0.45)
    for _ in range(7):
        rel = FI % rng.choice([1, 2, 3, 4, 5, 8, 9, 12, 13, 15])
        size = rng.uniform(34, 80)
        for _ in range(60):
            x, y = rng.uniform(-M + 10, w + M - size - 10), rng.uniform(-M + 10, h + M - size)
            if off_island(x + size / 2, y + size / 2, 60 + size / 2) and not near_gate(x + size / 2, y + size / 2, 140):
                cv.paste(_sprite(rel, size, (np.array(tint) * 0.9 + 0.1).tolist(), haze=haze), x, y, 0.9)
                break
    names = [f"medium_{i:02d}" for i in range(6, 38)] + [f"large_{i:02d}" for i in (1, 2, 3, 4, 9)] + [f"small_{i:02d}" for i in range(17, 32)]
    placed = 0
    for _ in range(int((w + h) / 9)):
        if placed >= int((w + h) / 24):
            break
        name = rng.choice(names)
        size = rng.uniform(50, 130) if name.startswith(("medium", "large")) else rng.uniform(28, 60)
        x, y = rng.uniform(-M - size / 2, w + M - size / 2), rng.uniform(-M - 20, h + M - 20)
        if not off_island(x + size / 2, y + size * 0.3, 10):
            continue
        cv.paste(_sprite(CLOUDS % name, size, tint), x, y, rng.uniform(0.75, 1.0))
        placed += 1

    # 3. Cliffs.
    rock = pack.synthesize([(pack.crop(*ROCK), 1.0)], AW, AH, seed + 31, patch=40, step=24) * np.array(rock_tint)
    lip_src = [(pack.crop(rel, box), wt) for rel, box, wt in lip_sources] if lip_sources else [(pack.crop(*GRASS), 1.0)]
    small = min(min(s.shape[:2]) for s, _ in lip_src)
    grass = pack.synthesize(lip_src, AW, AH, seed + 33, patch=min(40, small - 2), step=min(24, small // 2)) * np.array(lip_tint) * 0.92

    def put(mask: np.ndarray, color: np.ndarray, y0: int, x0: int) -> None:
        h_, w_ = mask.shape
        sub = arr[y0:y0 + h_, x0:x0 + w_]
        m = mask[:sub.shape[0], :sub.shape[1]]
        sub[m, :3] = color[:sub.shape[0], :sub.shape[1]][m]
        sub[m, 3] = 1.0

    # South cliff.
    cx0, _ = cv.px(ix0 - 20, 0)
    cx1, _ = cv.px(ix1 + 20, 0)
    _, top = cv.px(0, iy1)
    nx = cx1 - cx0
    t = np.linspace(-1, 1, nx)
    noise_x = pixel.fbm(nx, 1, 36.0 * K, seed + 21, 3)[0]
    height = (62 + 50 * noise_x) * (1.0 - 0.75 * np.abs(t) ** 5) * K
    ragged = (pixel.fbm(nx, 1, 5.0, seed + 25, 2)[0] - 0.5) * 14 * K
    span = min(int(height.max() + 20 * K), AH - top)
    ys = np.arange(span)[:, None]
    depth = ys / np.maximum(1.0, height + ragged)[None, :]
    cliff = depth < 1.0
    shade = np.clip(1.0 - depth * 0.55, 0.35, 1.0)[..., None]
    col = rock[top:top + span, cx0:cx1] * shade
    soil = ys[:, 0] < 5 * K
    col[soil] = col[soil] * 0.6 + np.array([0.36, 0.24, 0.16]) * 0.4
    put(cliff, col, top, cx0)
    lip = (4 + pixel.fbm(nx, 1, 3.0, seed + 27, 2)[0] * 8) * K
    lipmask = ys < lip[None, :]
    put(lipmask, grass[top:top + span, cx0:cx1], top, cx0)
    under = (ys >= lip[None, :]) & (ys < lip[None, :] + 3) & cliff
    region = arr[top:top + span, cx0:cx1]
    region[under, :3] *= 0.55
    if vines:
        for _ in range((ix1 - ix0) // 9):
            x = rng.uniform(0, nx - 4)
            if height[int(x)] > 30 * K:
                _vine(arr, cx0 + x, top + lip[int(x)] - 2, rng.uniform(14, min(height[int(x)] * 0.8, 70 * K)), rng)

    # Waterfalls into the clouds.
    spots = []
    for _ in range(falls):
        for _ in range(40):
            fx = rng.uniform(ix0 + (ix1 - ix0) * 0.12, ix1 - (ix1 - ix0) * 0.12)
            if not near_gate(fx, iy1, 160) and all(abs(fx - f) > 260 for f in spots):
                spots.append(fx)
                break
    for fx in spots:
        x0, _ = cv.px(fx, 0)
        hx = height[x0 - cx0]
        width = int(rng.uniform(14, 20) * K)
        streak = np.random.default_rng(int(fx)).random(width)
        y_start = top + int(lip[x0 - cx0])
        y_end = min(AH, top + int(hx) + 40 * K)
        edge = np.minimum(np.arange(width), width - 1 - np.arange(width)) / (width / 2)
        for y in range(y_start, y_end):
            fade = 1.0 - max(0.0, (y - (top + hx * 0.9)) / (y_end - (top + hx * 0.9) + 1))
            c = np.array(fall_color)[None, :] * (0.86 + 0.22 * streak[:, None]) + 0.22 * (((y + (streak * 40).astype(int)) % 14) < 4)[:, None]
            a = (np.minimum(1.0, edge * 3.0) * fade * 0.97)[:, None]
            seg = arr[y, x0:x0 + width, :3]
            arr[y, x0:x0 + width, :3] = seg * (1 - a) + np.clip(c, 0, 1) * a
        mist_y = (top + hx) / K - M + 4
        for _ in range(3):
            cv.paste(_sprite(CLOUDS % rng.choice(["small_22", "small_23", "small_29"]), rng.uniform(26, 40), tint), fx - 14 + rng.uniform(-8, 8), mist_y + rng.uniform(-6, 10), 0.9)

    # Side walls: thickening to the south, grass lip on the island side.
    _, ry0 = cv.px(0, iy0)
    _, ry1 = cv.px(0, iy1)
    nh = ry1 - ry0
    s = np.linspace(0, 1, nh)
    for side, seed_off in (("left", 41), ("right", 43)):
        noise_y = pixel.fbm(1, nh, 36.0 * K, seed + seed_off, 3)[:, 0]
        wall = ((5 + 22 * s ** 2) + noise_y * 8) * K
        lipw = (3 + pixel.fbm(1, nh, 3.0, seed + seed_off + 4, 2)[:, 0] * 7) * K
        reach = int((wall + lipw).max()) + 2
        if side == "left":
            ex, _ = cv.px(ix0, 0)
            xa = ex - reach
            dist = (ex - 1 - np.arange(xa, ex))[None, :].repeat(nh, 0)
        else:
            ex, _ = cv.px(ix1, 0)
            xa = ex
            dist = (np.arange(ex, ex + reach) - ex)[None, :].repeat(nh, 0)
        body = dist < (lipw + wall)[:, None]
        rock_part = body & (dist >= lipw[:, None])
        grass_part = dist < lipw[:, None]
        sl = (slice(ry0, ry1), slice(xa, xa + reach))
        shade = np.clip(1.0 - (dist - lipw[:, None]) / np.maximum(1, wall[:, None]) * 0.5, 0.4, 1)[..., None]
        put(rock_part, rock[sl] * shade, ry0, xa)
        put(grass_part, grass[sl], ry0, xa)
        if vines:
            for _ in range((iy1 - iy0) // 30):
                y = rng.uniform(0, nh - 40)
                x = (ex - lipw[int(y)] - 3) if side == "left" else (ex + lipw[int(y)] + 1)
                _vine(arr, x, ry0 + y, rng.uniform(10, 40), rng)

    # North rim: the grass edge seen from above, a thin shadow under it.
    lx0, ly = cv.px(ix0 - 4, iy0)
    lx1, _ = cv.px(ix1 + 4, iy0)
    lipn = (2 + pixel.fbm(lx1 - lx0, 1, 3.0, seed + 53, 2)[0] * 6) * K
    for i, x in enumerate(range(lx0, lx1)):
        n = int(lipn[i])
        arr[ly - n:ly, x, :3] = grass[ly - n:ly, x]
        arr[ly - n:ly, x, 3] = 1.0
        arr[ly - n - 2:ly - n, x, :3] *= 0.6

    # 4. Bridges at the exits (from the island edge out past the map edge).
    for gx, gy in gate_spots:
        _bridge(cv, gx, gy, (ix0, iy0, ix1, iy1), w, h)

    # 5. The outer rim fades out (only seen on the title screen).
    gyw = np.arange(AH) / K - M
    gxw = np.arange(AW) / K - M
    edge = np.minimum.outer(np.minimum(gyw + M, h + M - gyw), np.minimum(gxw + M, w + M - gxw))
    arr[:, :, 3] *= np.clip(edge / 46.0, 0, 1)

    img = (np.clip(arr, 0, 1) * 255).astype(np.uint8)
    mk = M * K
    out = {
        "top": Image.fromarray(img[:mk], "RGBA"),
        "bottom": Image.fromarray(img[mk + h * K:], "RGBA"),
        "left": Image.fromarray(img[mk:mk + h * K, :mk], "RGBA"),
        "right": Image.fromarray(img[mk:mk + h * K, mk + w * K:], "RGBA"),
    }
    if island is not None:
        inner = img[mk:mk + h * K, mk:mk + w * K].copy()
        # Inside the island the ground shows through.
        inner[int(iy0 * K):int(iy1 * K), int(ix0 * K):int(ix1 * K), 3] = 0
        out["inner"] = Image.fromarray(inner, "RGBA")
    return out


def _bridge(cv: Canvas, gx: float, gy: float, island: tuple, w: int, h: int) -> None:
    ix0, iy0, ix1, iy1 = island
    edges = {"left": gx - ix0, "right": ix1 - gx, "top": gy - iy0, "bottom": iy1 - gy}
    side = min(edges, key=edges.get)
    if edges[side] > 120:
        return
    deck = pack.content(pack.image("props/prop_018.png"))
    if side in ("left", "right"):
        start = ix0 if side == "left" else ix1
        end = -M + 18 if side == "left" else w + M - 18
        length = abs(start - end)
        img = deck.resize((int(length * K), int(length * K * deck.height / deck.width)), Image.LANCZOS)
        arr = np.asarray(img, np.float32) / 255.0
        cv.paste(arr, min(start, end), gy - arr.shape[0] / K / 2 - 2)
    else:
        start = iy0 if side == "top" else iy1
        end = -M + 18 if side == "top" else h + M - 18
        length = abs(start - end)
        mid = deck.crop((int(deck.width * 0.3), 0, int(deck.width * 0.7), deck.height))
        img = mid.rotate(90, expand=True)
        img = img.resize((int(length * K * img.width / img.height), int(length * K)), Image.LANCZOS)
        arr = np.asarray(img, np.float32) / 255.0
        cv.paste(arr, gx - arr.shape[1] / K / 2, min(start, end))
