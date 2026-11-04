"""Sky apron around an outdoor region: the map is the top of a floating
island, so beyond its edges we see the cliff it stands on (deep under the
south rim, a thin wall on the sides), hanging roots, the cloud sea far below,
small floating rocks and rope bridges leaving from the region's exits.

Saved as four strips (top, bottom, left, right) to keep files small; the
game places them around the map (scripts/world.gd)."""
from __future__ import annotations

import random

import numpy as np

from pixel import Canvas, fbm, hex_color

MARGIN = 160

DAY_SKY = [(150, 196, 240, 255), (170, 210, 246, 255), (192, 224, 250, 255), (214, 236, 252, 255)]
DAY_CLOUD = [(206, 222, 244, 255), (226, 236, 250, 255), (242, 247, 253, 255), (255, 255, 255, 255)]
NIGHT_SKY = [(34, 40, 82, 255), (44, 52, 100, 255), (58, 66, 120, 255), (74, 82, 140, 255)]
NIGHT_CLOUD = [(70, 80, 134, 255), (88, 98, 152, 255), (108, 118, 170, 255), (130, 140, 190, 255)]
NIGHT_STYLES = ("night", "marsh", "rift")


def _rgba(color) -> np.ndarray:
    return np.array(color if len(color) == 4 else (*color, 255), dtype=np.uint8)


def render(terrain: dict, pal: dict, seed: int) -> dict[str, Canvas]:
    w, h = terrain["size"]
    m = MARGIN
    W, H = w + 2 * m, h + 2 * m
    night = terrain.get("style") in NIGHT_STYLES
    sky = NIGHT_SKY if night else DAY_SKY
    cloud = NIGHT_CLOUD if night else DAY_CLOUD
    stone = pal["stone"]
    dirt = pal["dirt"]
    leaf = pal["leaf"]
    rng = random.Random(seed)
    img = np.zeros((H, W, 4), dtype=np.uint8)

    # 1. Sky: soft bands, then the cloud sea, thicker away from the island.
    ys, xs = np.mgrid[0:H, 0:W]
    dx = np.maximum(np.maximum(m - xs, xs - (m + w - 1)), 0)
    dy = np.maximum(np.maximum(m - ys, ys - (m + h - 1)), 0)
    dist = np.sqrt(dx.astype(np.float32) ** 2 + dy.astype(np.float32) ** 2)
    band = (fbm(W, H, 90.0, seed + 3, 2) * 3.99).astype(int)
    img[:] = np.array(sky, dtype=np.uint8)[np.clip(band, 0, 3)]
    puffs = fbm(W, H, 34.0, seed + 11, 4) + np.clip(dist / m, 0, 1) * 0.22
    for level, threshold in enumerate((0.55, 0.62, 0.69, 0.76)):
        img[puffs > threshold] = cloud[level]

    # 2. Cliff under the island. Bottom: tall, tapering towards the corners,
    # with a ragged underside of hanging rock.
    noise_x = fbm(W, 1, 18.0, seed + 21, 3)[0]
    noise_y = fbm(1, H, 18.0, seed + 23, 3)[:, 0]
    grain = fbm(W, H, 5.0, seed + 31, 2)
    cliff = np.zeros((H, W), dtype=bool)
    depth = np.zeros((H, W), dtype=np.float32)
    layer = np.zeros((H, W), dtype=np.int32)
    for x in range(m - 22, m + w + 22):
        t = (x - (m + w / 2)) / (w / 2 + 22)
        height = (64 + 46 * noise_x[x]) * (1.0 - 0.7 * min(1.0, abs(t)) ** 4)
        height += rng.choice((0, 0, 0, 3, 6, 10, -3))   # stalactite fringe
        height = int(max(10, height))
        top = m + h
        cliff[top:top + height, x] = True
        depth[top:top + height, x] = np.arange(height) / max(1, height)
        layer[top:top + height, x] = np.arange(height)
    # Sides: a wall that grows thicker towards the south.
    for y in range(m - 2, m + h):
        s = (y - m) / h
        width = int(5 + 16 * s ** 2 + 5 * noise_y[y])
        for x0, x1, flip in ((m - width, m, True), (m + w, m + w + width, False)):
            cliff[y, x0:x1] = True
            ramp_ = np.linspace(1, 0, width) if flip else np.linspace(0, 1, width)
            depth[y, x0:x1] = ramp_
            layer[y, x0:x1] = (y - m) // 2 + 8
    # Top rim: just a dark lip; we look down on it.
    cliff[m - 3:m, m - 2:m + w + 2] = True
    depth[m - 3:m, m - 2:m + w + 2] = 0.3
    layer[m - 3:m, m - 2:m + w + 2] = 12

    # Colours: soil band, then rock strata (light, mid, earthy), darker deeper.
    soil = np.array([_rgba(dirt[i]) for i in (3, 2, 1)])
    rock = np.array([_rgba(stone[4]), _rgba(stone[3]), _rgba(dirt[2]), _rgba(stone[3]), _rgba(stone[2])])
    wobble = (noise_x[xs] * 8).astype(int)
    stratum = ((layer + wobble) // 7) % len(rock)
    colors = rock[stratum]
    darker = (depth > 0.55) | (grain < 0.35)
    colors[darker] = np.array(_rgba(stone[2]))
    colors[(depth > 0.8)] = np.array(_rgba(stone[1]))
    colors[layer < 3] = soil[0]
    colors[(layer >= 3) & (layer < 7)] = soil[1]
    colors[(layer >= 7) & (layer < 9)] = soil[2]
    img[cliff] = colors[cliff]
    seam = cliff & ((layer + wobble) % 7 == 0) & (layer > 9)
    img[seam] = _rgba(stone[1])

    canvas = Canvas(W, H)
    canvas.px = img

    # 3. Hanging roots and vines over the south cliff.
    for _ in range(w // 8):
        x = rng.randint(m, m + w - 1)
        length = rng.randint(6, 30)
        color = leaf[rng.randint(2, 4)] if rng.random() < 0.65 else dirt[1]
        sway = rng.choice((-1, 0, 1))
        for i in range(length):
            px = x + (sway if i > length // 2 else 0)
            canvas.put(px, m + h + 1 + i, color)
        if rng.random() < 0.5:
            canvas.put(x + sway, m + h + 1 + length, leaf[5])

    # 4. The underside fades into the clouds below.
    veil = fbm(W, H, 20.0, seed + 41, 3)
    fade = np.clip((depth - 0.35) / 0.65, 0, 1) ** 1.4 * 0.9 + (veil - 0.5) * 0.5
    fade = np.clip(fade, 0, 1)[..., None]
    bottom_zone = cliff & (ys >= m + h)
    target = np.array(_rgba(cloud[2]), dtype=np.float32)
    blended = img.astype(np.float32) * (1 - fade) + target * fade
    img[bottom_zone] = blended[bottom_zone].astype(np.uint8)

    # 5. Small floating rocks with grassy tops drifting near the island.
    for _ in range(9):
        side = rng.choice(("left", "right", "bottom", "top"))
        if side == "left":
            cx, cy = rng.randint(30, m - 50), rng.randint(m + 40, m + h - 40)
        elif side == "right":
            cx, cy = rng.randint(m + w + 50, W - 30), rng.randint(m + 40, m + h - 40)
        elif side == "top":
            cx, cy = rng.randint(m, m + w), rng.randint(30, m - 50)
        else:
            cx, cy = rng.randint(m, m + w), rng.randint(m + h + 125, H - 20)
        r = rng.randint(7, 15)
        for yy in range(0, r + 1):
            half = int(r * (1 - (yy / (r + 1)) ** 1.6))
            for xx in range(-half, half + 1):
                canvas.put(cx + xx, cy + yy, stone[3] if xx < 0 else stone[2])
        canvas.ellipse(cx, cy, r + 0.5, 3.2, leaf[3])
        canvas.ellipse(cx - 1, cy - 1, r - 2, 2.0, leaf[4])

    # 6. Rope bridges from the exits out into the sky.
    gates = list(terrain.get("_gates", []))
    for gx, gy in gates:
        _bridge(canvas, int(gx) + m, int(gy) + m, w, h, m, pal)
    # Trails that run off the island without an exit end at a broken bridge.
    for trail in terrain.get("trails", []):
        for px, py in (trail[0], trail[-1]):
            if not (px <= 4 or py <= 4 or px >= w - 4 or py >= h - 4):
                continue
            if any(abs(px - gx) + abs(py - gy) < 120 for gx, gy in gates):
                continue
            _bridge(canvas, int(px) + m, int(py) + m, w, h, m, pal, length=26)
    # Outer rim fades out: unseen in play (the camera stops 110 px out), it
    # lets the title screen float the island on its own sky.
    outer = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, H - 1 - ys)).astype(np.float32)
    alpha = np.clip(outer / 46.0, 0.0, 1.0)
    img[..., 3] = (img[..., 3].astype(np.float32) * alpha).astype(np.uint8)
    return {
        "top": _crop(canvas, 0, 0, W, m),
        "bottom": _crop(canvas, 0, m + h, W, m),
        "left": _crop(canvas, 0, m, m, h),
        "right": _crop(canvas, m + w, m, m, h),
    }


def _crop(canvas: Canvas, x: int, y: int, w: int, h: int) -> Canvas:
    part = Canvas(w, h)
    part.px = canvas.px[y:y + h, x:x + w].copy()
    return part


def _bridge(canvas: Canvas, gx: int, gy: int, w: int, h: int, m: int, pal, length: int = 0) -> None:
    plank = [hex_color("#c89a64"), hex_color("#a57848"), hex_color("#7a5434"), hex_color("#4e3424")]
    rope = hex_color("#e8d8b0")
    edges = {"left": gx - m, "right": m + w - gx, "top": gy - m, "bottom": m + h - gy}
    side = min(edges, key=edges.get)
    if edges[side] > 90:
        return
    if side in ("left", "right"):
        step = -1 if side == "left" else 1
        start = m if side == "left" else m + w - 1
        x = start
        span = length or m - 20
        for i in range(span):
            x = start + step * i
            sag = int(3 * np.sin(i / (m - 20) * np.pi)) + (i - span + 8 if length and i > span - 8 else 0)
            for dy in range(-7, 8):
                color = plank[1] if dy in (-7, 7) else (plank[0] if (i // 4) % 2 == 0 else plank[1])
                if i % 4 == 3:
                    color = plank[3]
                canvas.put(x, gy + dy + sag, color)
            canvas.put(x, gy - 9 + sag, rope)
            canvas.put(x, gy + 9 + sag, rope)
            if i % 12 == 0:
                for k in range(-12, -8):
                    canvas.put(x, gy + k + sag, plank[2])
                    canvas.put(x, gy - k + sag, plank[2])
    else:
        step = -1 if side == "top" else 1
        start = m if side == "top" else m + h - 1
        span = length or m - 20
        for i in range(span):
            y = start + step * i
            sag = int(3 * np.sin(i / (m - 20) * np.pi)) + (i - span + 8 if length and i > span - 8 else 0)
            for dx in range(-7, 8):
                color = plank[1] if dx in (-7, 7) else (plank[0] if (i // 4) % 2 == 0 else plank[1])
                if i % 4 == 3:
                    color = plank[3]
                canvas.put(gx + dx + sag, y, color)
            canvas.put(gx - 9 + sag, y, rope)
            canvas.put(gx + 9 + sag, y, rope)
            if i % 12 == 0:
                for k in range(-12, -8):
                    canvas.put(gx + k + sag, y, plank[2])
                    canvas.put(gx - k + sag, y, plank[2])


def cloud_puff(seed: int, night: bool) -> tuple[Canvas, tuple[int, int]]:
    """A loose cloud that drifts under the island (z below the ground)."""
    rng = random.Random(seed)
    colors = NIGHT_CLOUD if night else DAY_CLOUD
    w, h = rng.randint(70, 110), rng.randint(26, 38)
    c = Canvas(w, h)
    for _ in range(9):
        cx, cy = rng.uniform(14, w - 14), rng.uniform(h * 0.45, h - 10)
        rx = rng.uniform(9, 18)
        c.ellipse(cx, cy, rx, rx * 0.7, colors[1])
    for _ in range(6):
        cx, cy = rng.uniform(16, w - 16), rng.uniform(h * 0.35, h * 0.7)
        rx = rng.uniform(7, 13)
        c.ellipse(cx, cy - 2, rx, rx * 0.6, colors[3])
    return c, (w // 2, h // 2)
