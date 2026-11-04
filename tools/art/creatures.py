"""Enemies and spell projectiles. Same lighting rules as the humanoid rig."""
from __future__ import annotations

import math
import random

import numpy as np

from characters import MIRROR, ROW_ORDER, r4
from pixel import Canvas, hex_color

ANGLES = {"down": 90, "down_right": 45, "right": 0, "up_right": -45, "up": -90,
          "up_left": -135, "left": 180, "down_left": 135}


class Body:
    """Like characters.Sprite, but for any square size."""

    def __init__(self, size: int) -> None:
        self.n = size
        self.px = np.zeros((size, size, 4), dtype=np.uint8)
        self.owner = np.full((size, size), -1, dtype=int)
        self.parts = 0
        ys, xs = np.mgrid[0:size, 0:size] + 0.5
        self.xs, self.ys = xs, ys

    def ellipse(self, cx, cy, rx, ry) -> np.ndarray:
        return ((self.xs - cx) / rx) ** 2 + ((self.ys - cy) / ry) ** 2 <= 1.0

    def rect(self, x0, y0, x1, y1) -> np.ndarray:
        return (self.xs >= x0) & (self.xs <= x1 + 1) & (self.ys >= y0) & (self.ys <= y1 + 1)

    def part(self, mask, ramp, sphere=None, separate=True) -> None:
        part_id = self.parts
        self.parts += 1
        n = self.n
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            right = x < n - 1 and mask[y, x + 1]
            down = y < n - 1 and mask[y + 1, x]
            left = x > 0 and mask[y, x - 1]
            up = y > 0 and mask[y - 1, x]
            if sphere is not None:
                cx, cy, r = sphere
                nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                lit = -0.6 * nx - 0.7 * ny + 0.5 * nz
                level = 0 if lit > 0.62 else (1 if lit > 0.12 else 2)
            else:
                level = 0 if (not left or not up) else (2 if (not right or not down) else 1)
            color = ramp[level]
            if separate and self.px[y, x, 3] and self.owner[y, x] != part_id and (not right or not down):
                color = ramp[min(3, level + 1)]
            self.px[y, x] = color
            self.owner[y, x] = part_id

    def dot(self, x, y, color) -> None:
        if 0 <= x < self.n and 0 <= y < self.n:
            self.px[int(y), int(x)] = color

    def shadow(self, cx, cy, rx, ry, alpha=70) -> None:
        m = self.ellipse(cx, cy, rx, ry)
        self.px[m] = (16, 24, 32, alpha)
        self.owner[m] = -2

    def outline(self, color) -> None:
        m = (self.px[:, :, 3] > 0) & (self.owner != -2)
        grown = m.copy()
        grown[1:, :] |= m[:-1, :]
        grown[:-1, :] |= m[1:, :]
        grown[:, 1:] |= m[:, :-1]
        grown[:, :-1] |= m[:, 1:]
        edge = grown & ~m
        self.px[edge] = color

    def canvas(self) -> Canvas:
        c = Canvas(self.n, self.n)
        c.px = self.px.copy()
        return c


def build_sheet(draw_fn, size: int) -> Canvas:
    out = Canvas(size * 4, size * 8)
    for row, direction in enumerate(ROW_ORDER):
        facing = MIRROR.get(direction, direction)
        for frame in range(4):
            out.paste(draw_fn(facing, frame), frame * size, row * size, flip=direction in MIRROR)
    return out


# --- slime ----------------------------------------------------------------------

GEL = r4("#d4f7a0", "#8fd862", "#4fa04e", "#2a6a44")


def slime(facing: str, frame: int) -> Canvas:
    b = Body(32)
    squash = [(9.5, 7.0), (8.6, 8.0), (9.8, 6.6), (8.8, 7.6)][frame]
    rx, ry = squash
    cy = 28 - ry
    b.shadow(16, 29, 9, 2.2)
    body = b.ellipse(16, cy, rx, ry) & (b.ys < 29)
    b.part(body, GEL, sphere=(13, cy - 3, rx + 3))
    # Darker translucent core and a glossy highlight.
    b.part(b.ellipse(17, cy + 2, rx * 0.45, ry * 0.4) & body, r4("#6fbf58", "#5aa850", "#4a9048", "#3a7a40"), separate=False)
    b.dot(11, cy - ry + 3, hex_color("#ffffff"))
    b.dot(12, cy - ry + 2, hex_color("#ffffff"))
    b.dot(11, cy - ry + 2, GEL[0])
    eye, white = hex_color("#1d2a33"), hex_color("#ffffff")
    ey = int(cy) - 1
    if facing in ("down", "down_right", "right"):
        xs = {"down": [12, 19], "down_right": [15, 21], "right": [21]}[facing]
        for x in xs:
            b.dot(x, ey, eye)
            b.dot(x, ey + 1, eye)
            b.dot(x, ey, white)
        mouth = {"down": 15, "down_right": 18, "right": 22}[facing]
        b.dot(mouth, ey + 3, eye)
        b.dot(mouth + 1, ey + 3, eye)
    # A little leaf sprout on top, visible from every side.
    top = int(cy - ry)
    leaf = r4("#b8f07a", "#6fc24c", "#3f8a3e", "#24583a")
    b.part(b.rect(15, top - 2, 15, top), r4("#8a6a3a", "#6a4c2c", "#4a3424", "#33241c"), separate=False)
    lean = 1 if frame in (1, 3) else 0
    b.part(b.ellipse(18 + lean, top - 3, 2.6, 1.5), leaf, separate=False)
    b.outline(hex_color("#173a33"))
    return b.canvas()


# --- wolf -----------------------------------------------------------------------

FUR = r4("#c9d4e6", "#8c9ab8", "#5d6a8c", "#3b4463")
BELLY = r4("#f4f6fa", "#d6dce8", "#aab4c8", "#7a849c")
DARK = r4("#5d6a8c", "#3b4463", "#2a3048", "#1b1f33")


def wolf(facing: str, frame: int) -> Canvas:
    b = Body(32)
    eye = hex_color("#ffd45c")
    nose = hex_color("#1b1f33")
    stride = [2, 0, -2, 0][frame]
    bob = 1 if frame in (1, 3) else 0
    b.shadow(16, 29, 10, 2.2)
    if facing == "right":
        # Tail, back legs, body, front legs, head.
        b.part(b.ellipse(6, 16 - bob, 2.2, 4.5) | b.ellipse(5, 13 - bob, 1.8, 2.5), FUR)
        for lx, off in ((10, -stride), (13, stride)):
            b.part(b.rect(lx + off // 2, 21, lx + 1 + off // 2, 27 - (1 if frame in (1, 3) and lx == 10 else 0)), DARK)
        b.part(b.ellipse(15, 19 - bob, 8.5, 4.6), FUR, sphere=(12, 15, 10))
        b.part(b.ellipse(16, 22 - bob, 6, 1.6), BELLY, separate=False)
        for lx, off in ((19, stride), (22, -stride)):
            b.part(b.rect(lx + off // 2, 21, lx + 1 + off // 2, 27 - (1 if frame in (1, 3) and lx == 22 else 0)), FUR)
        hx, hy = 24, 14 - bob
        b.part(b.ellipse(hx, hy, 4.4, 4.0), FUR, sphere=(hx - 1, hy - 2, 5))
        b.part(b.ellipse(hx + 4, hy + 1.5, 2.6, 1.8), BELLY, separate=False)
        b.dot(hx + 6, hy + 1, nose)
        b.part(b.rect(hx - 2, hy - 6, hx - 1, hy - 3) | b.rect(hx + 1, hy - 6, hx + 2, hy - 3), DARK, separate=False)
        b.dot(hx + 2, hy - 1, eye)
        b.part(b.ellipse(hx - 2, hy + 3, 2.4, 2), BELLY, separate=False)
    elif facing in ("down", "down_right"):
        sx = 2 if facing == "down_right" else 0
        b.part(b.ellipse(16 - sx, 20 - bob, 7.5 + sx, 5), FUR, sphere=(13, 16, 9))
        for lx, lift in ((12 + sx, frame == 0), (18 + sx, frame == 2)):
            b.part(b.rect(lx, 22, lx + 1, 27 - int(lift)), FUR)
            b.dot(lx, 27 - int(lift), BELLY[2])
            b.dot(lx + 1, 27 - int(lift), BELLY[2])
        hx, hy = 16 + sx, 14 - bob
        b.part(b.ellipse(hx, hy + 5, 3.8, 3), BELLY, separate=False)   # chest ruff
        b.part(b.ellipse(hx, hy, 5.4, 4.6), FUR, sphere=(hx - 2, hy - 2, 6))
        for ex in (hx - 4, hx + 3):
            b.part(b.rect(ex, hy - 7, ex + 1, hy - 3), DARK, separate=False)
            b.dot(ex + (1 if ex < hx else 0), hy - 4, BELLY[2])
        b.part(b.ellipse(hx + sx // 2, hy + 2.5, 2.6, 2), BELLY, separate=False)
        b.dot(hx + sx // 2, hy + 2, nose)
        eyes = [hx - 2, hx + 2] if not sx else [hx, hx + 3]
        for ex in eyes:
            b.dot(ex, hy, eye)
            b.dot(ex, hy - 1, DARK[2])
    else:
        sx = 2 if facing == "up_right" else 0
        for lx, lift in ((12 + sx, frame == 0), (18 + sx, frame == 2)):
            b.part(b.rect(lx, 22, lx + 1, 27 - int(lift)), DARK)
        b.part(b.ellipse(16 + sx, 19 - bob, 7 + sx * 0.5, 6), FUR, sphere=(13, 15, 9))
        hx, hy = 16 + sx * 2, 11 - bob
        b.part(b.ellipse(hx, hy, 4.6, 4), FUR, sphere=(hx - 1, hy - 2, 5))
        for ex in (hx - 4, hx + 3):
            b.part(b.rect(ex, hy - 7, ex + 1, hy - 3), DARK, separate=False)
        wag = [0, 1, 0, -1][frame]
        b.part(b.ellipse(16 + wag - sx, 24, 2.2, 3.8), FUR)
        b.dot(16 + wag - sx, 27, BELLY[1])
    b.outline(hex_color("#151a2c"))
    return b.canvas()


# --- grove guardian (boss, 48 px) ---------------------------------------------

ROCK = r4("#b9c2b8", "#8a968e", "#5f6a66", "#3e4648")
MOSS = r4("#b8f07a", "#6fc24c", "#3f8a3e", "#24583a")
BARK = r4("#a9744d", "#86573f", "#633d32", "#43292a")


def guardian(facing: str, frame: int) -> Canvas:
    b = Body(48)
    glow = hex_color("#ffd45c")
    core = hex_color("#fff2b0")
    stride = [2, 0, -2, 0][frame]
    bob = 1 if frame in (1, 3) else 0
    back = facing in ("up", "up_right")
    side = facing == "right"
    b.shadow(24, 44, 16, 3.5, 80)
    # Stumpy legs.
    for lx, off in ((15, stride), (27, -stride)):
        if side:
            lx = 19 + (off * 2)
        b.part(b.rect(lx, 34, lx + 5, 43 - (1 if off > 0 and frame in (1, 3) else 0)), BARK)
    # Massive rocky torso.
    tx = 24 + (2 if side else 0)
    b.part(b.ellipse(tx, 27 - bob, 13 if not side else 10, 11), ROCK, sphere=(19, 20, 15))
    # Moss mantle over the shoulders.
    mantle = b.ellipse(tx, 19 - bob, 13 if not side else 10, 6) & (b.ys < 22 - bob)
    b.part(mantle, MOSS, sphere=(19, 14, 14))
    for x in range(tx - 12, tx + 12, 3):
        b.dot(x, 22 - bob + (x % 2), MOSS[2])
    # Arms: big stone fists that swing.
    if not side:
        for ax, swing in ((tx - 16, stride), (tx + 11, -stride)):
            b.part(b.rect(ax, 20 - bob + max(0, swing), ax + 4, 31 - bob + max(0, swing)), ROCK)
            b.part(b.ellipse(ax + 2.5, 33 - bob + max(0, swing), 3.6, 3), ROCK)
    else:
        b.part(b.rect(tx - 2 + stride, 21 - bob, tx + 2 + stride, 32 - bob), ROCK)
        b.part(b.ellipse(tx + stride, 34 - bob, 3.6, 3), ROCK)
    # Head: a smaller boulder with a bark brow and glowing eyes.
    hx, hy = tx + (3 if side else (2 if facing == "down_right" else 0)), 11 - bob
    b.part(b.ellipse(hx, hy, 7, 6), ROCK, sphere=(hx - 2, hy - 3, 8))
    b.part(b.ellipse(hx, hy - 4, 7, 2.5) & (b.ys < hy - 3), MOSS, separate=False)
    for sx in (-5, 3):
        if side and sx < 0:
            continue
        b.part(b.rect(hx + sx, hy - 9, hx + sx + 1, hy - 5) | b.rect(hx + sx - 1, hy - 10, hx + sx - 1, hy - 9), BARK, separate=False)
    if not back:
        eyes = [hx - 3, hx + 2] if not side else [hx + 3]
        for ex in eyes:
            b.dot(ex, hy, glow)
            b.dot(ex + 1, hy, glow)
            b.dot(ex, hy + 1, core)
        # Glowing rune core in the chest.
        cx, cy = tx + (2 if side else 0), 27 - bob
        for dx, dy in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
            b.dot(cx + dx, cy + dy, core if abs(dx) + abs(dy) <= 1 else glow)
    else:
        for y in range(18 - bob, 36 - bob, 4):
            b.dot(24 + (y % 3) - 1, y, ROCK[3])
    b.outline(hex_color("#1a2220"))
    return b.canvas()


# --- projectiles ----------------------------------------------------------------

def projectile(kind: str):
    """Returns draw(facing, frame) for a projectile flying along its facing."""
    palettes = {
        "fire": [hex_color("#fffbe0"), hex_color("#ffe066"), hex_color("#ff9a3c"), hex_color("#e8452e"), hex_color("#8f2a3a")],
        "frost": [hex_color("#ffffff"), hex_color("#c6f4ff"), hex_color("#7fd4ff"), hex_color("#3a8fe0"), hex_color("#28508a")],
        "lightning": [hex_color("#ffffff"), hex_color("#f2e6ff"), hex_color("#c9a2ff"), hex_color("#8a5ae8"), hex_color("#4a2f9a")],
    }
    pal = palettes[kind]

    def draw(facing: str, frame: int) -> Canvas:
        c = Canvas(32, 32)
        angle = math.radians(ANGLES[facing])
        dx, dy = math.cos(angle), math.sin(angle)
        rng = random.Random(frame * 31 + len(kind))
        for y in range(32):
            for x in range(32):
                px, py = x + 0.5 - 16, y + 0.5 - 16
                u = px * dx + py * dy          # along flight direction
                v = -px * dy + py * dx         # sideways
                if kind == "frost":
                    # Diamond shard: long tip forward, short tail back.
                    reach = 7.5 if u >= 0 else 4.0
                    width = 3.2 * (1 - abs(u) / reach) if abs(u) < reach else -1
                    if abs(v) <= width:
                        t = abs(v) / max(width, 0.01)
                        level = 0 if (v < 0 and t > 0.4) else (1 if t < 0.5 else 2)
                        if u > 4.5:
                            level = 0
                        c.put(x, y, pal[level])
                    elif u < 0 and abs(v) < 1.5 and -12 < u < -4 and (int(-u) + frame) % 3 == 0:
                        c.put(x, y, pal[2][:3] + (170,))
                    continue
                # Fire and lightning: a bright head with a flickering tail.
                tail = max(0.0, -u)
                flicker = math.sin(tail * 0.9 + frame * 1.7 + v) * 0.8
                radius = 4.6 - tail * 0.32 + flicker * 0.4
                if u > 0:
                    radius = 4.6 - u * 0.55
                d = abs(v)
                if radius > 0 and d <= radius and u > -13:
                    t = d / radius
                    core = (u > -3) and t < 0.45
                    level = 0 if core and t < 0.25 else (1 if core else (2 if t < 0.7 and tail < 6 else 3))
                    if tail > 9:
                        level = 4 if t > 0.5 else 3
                    c.put(x, y, pal[level])
        if kind == "lightning":
            # Crackling arcs around the orb.
            for _ in range(3):
                a = rng.uniform(0, math.tau)
                r0 = 4
                x, y = 16 + math.cos(a) * r0, 16 + math.sin(a) * r0
                for _ in range(4):
                    a += rng.uniform(-0.9, 0.9)
                    nx, ny = x + math.cos(a) * 2, y + math.sin(a) * 2
                    c.line(x, y, nx, ny, pal[1])
                    x, y = nx, ny
        if kind in ("fire", "frost"):
            # Sparks trailing behind.
            for i in range(3):
                t = 7 + i * 3 + (frame % 2)
                sx = 16 - dx * t + (-dy) * rng.uniform(-3, 3)
                sy = 16 - dy * t + dx * rng.uniform(-3, 3)
                c.put(sx, sy, pal[1] if kind == "frost" else pal[2])
        c.outline(pal[4][:3] + (200,))
        return c

    return draw


# --- crystal bat ----------------------------------------------------------------

WING = r4("#b8fbff", "#5fdcf0", "#2a9ec8", "#1a5a88")
BATFUR = r4("#8a7a9a", "#5a4a6a", "#3a2e48", "#221a30")


def bat(facing: str, frame: int) -> Canvas:
    """Hovering bat: wings flap through 4 frames; body bobs above its shadow."""
    b = Body(32)
    b.shadow(16, 29, 6, 1.6, 60)
    lift = [0, -2, -1, 1][frame]
    cy = 15 + lift
    span = [11, 7, 4, 9][frame]
    wing_y = [-3, -1, 2, 1][frame]
    side = facing == "right"
    back = facing in ("up", "up_right")
    if side:
        # Profile: one wing towards the camera, one behind.
        b.part(b.ellipse(14, cy + wing_y, span * 0.6, 3.5), WING)
        b.part(b.ellipse(16, cy, 4.2, 4.5), BATFUR, sphere=(15, cy - 2, 5))
        b.part(b.ellipse(19, cy - 1, 2.6, 2.4), BATFUR, separate=False)
        b.part(b.rect(17, cy - 6, 17, cy - 4) | b.rect(19, cy - 6, 19, cy - 4), BATFUR, separate=False)
        b.dot(20, cy - 1, hex_color("#9cfff0"))
        b.part(b.ellipse(17, cy + wing_y + 1, span * 0.7, 3.2), WING)
    else:
        for sign in (-1, 1):
            wing = b.ellipse(16 + sign * (span * 0.55 + 2), cy + wing_y, span * 0.6, 3.6)
            wing |= b.ellipse(16 + sign * (span * 0.9 + 2), cy + wing_y + 2, 2.0, 2.0)
            b.part(wing, WING)
            for k in range(1, 3):
                b.dot(16 + sign * (k * span // 3 + 2), cy + wing_y + 2, WING[3])
        b.part(b.ellipse(16, cy, 4.6, 5), BATFUR, sphere=(14, cy - 3, 6))
        for sign in (-1, 1):
            b.part(b.rect(16 + sign * 3 - (1 if sign < 0 else 0), cy - 7, 16 + sign * 3 - (1 if sign < 0 else 0), cy - 4), BATFUR, separate=False)
        if not back:
            sx = 1 if facing == "down_right" else 0
            for ex in (14 + sx, 18 + sx):
                b.dot(ex, cy - 1, hex_color("#9cfff0"))
            b.dot(15 + sx, cy + 2, hex_color("#ffffff"))
            b.dot(17 + sx, cy + 2, hex_color("#ffffff"))
        # Crystal growing on its back/head.
        b.dot(16, cy - 5, hex_color("#d0b8ff"))
        b.dot(16, cy - 6, hex_color("#f6f0ff"))
    b.outline(hex_color("#120e22"))
    return b.canvas()


# --- Echo Warden (act I boss, 48 px) -------------------------------------------

CRYSTAL = r4("#f6f0ff", "#c9b0ff", "#8a6ae8", "#4a34a8")
CORE = r4("#ffffff", "#9cfff0", "#3fd6d0", "#1f8a8a")


def echo_warden(facing: str, frame: int) -> Canvas:
    """A floating crystal colossus: faceted body, orbiting shards, glowing core."""
    b = Body(48)
    bob = [0, -1, -2, -1][frame]
    b.shadow(24, 44, 14, 3.2, 80)
    cy = 24 + bob
    back = facing in ("up", "up_right")
    side = facing == "right"
    # Orbiting shards behind the body.
    for k in range(3):
        angle = (frame * 0.5 + k * 2.1)
        sx = 24 + math.cos(angle) * 17
        sy = cy - 2 + math.sin(angle) * 6
        if math.sin(angle) < 0:
            b.part(b.ellipse(sx, sy, 2.2, 4), CRYSTAL)
    # Main faceted body: stacked diamond silhouette.
    w = 9 if side else 12
    body = np.zeros((48, 48), dtype=bool)
    for y in range(8 + bob, 40 + bob):
        t = (y - (8 + bob)) / 32
        half = w * (t * 2.2 if t < 0.45 else (1 - t) * 1.8 + 0.1)
        x0, x1 = int(24 - half), int(24 + half)
        if x1 > x0:
            body[y, max(0, x0):min(48, x1 + 1)] = True
    b.part(body, CRYSTAL, sphere=(19, cy - 6, 16))
    # Facet lines.
    for y in range(12 + bob, 36 + bob, 5):
        for x in range(24 - w, 24 + w):
            if body[y, x] and (x + y) % 3 == 0:
                b.dot(x, y, CRYSTAL[3])
    if not back:
        # Core and eyes.
        core_x = 24 + (3 if side else (2 if facing == "down_right" else 0))
        b.part(b.ellipse(core_x, cy + 2, 3.6, 3.6), CORE, separate=False)
        b.dot(core_x - 1, cy + 1, hex_color("#ffffff"))
        eye_y = cy - 9
        eyes = [core_x - 4, core_x + 3] if not side else [core_x + 3]
        for ex in eyes:
            b.dot(ex, eye_y, CORE[1])
            b.dot(ex + 1, eye_y, CORE[1])
    # Shards in front.
    for k in range(3):
        angle = (frame * 0.5 + k * 2.1)
        sx = 24 + math.cos(angle) * 17
        sy = cy - 2 + math.sin(angle) * 6
        if math.sin(angle) >= 0:
            b.part(b.ellipse(sx, sy, 2.2, 4), CRYSTAL)
    b.outline(hex_color("#1a1030"))
    return b.canvas()


# --- Sky Sentinel (Keepers' construct) ------------------------------------------

MARBLE = r4("#f8f8fc", "#c6cadc", "#8a8ca8", "#5a5a7a")
BRASS = r4("#fff2a8", "#ffd45c", "#d99a2e", "#8a5a22")


def sentinel(facing: str, frame: int) -> Canvas:
    """Floating marble construct with a brass collar and one glowing eye."""
    b = Body(32)
    bob = [0, -1, -1, 0][frame]
    b.shadow(16, 29, 7, 1.8, 70)
    side = facing == "right"
    back = facing in ("up", "up_right")
    cy = 17 + bob
    b.part(b.ellipse(16, cy + 5, 5 if not side else 4, 6), MARBLE, sphere=(14, cy + 2, 7))
    b.part(b.rect(10 if not side else 12, cy - 1, 21 if not side else 19, cy + 1), BRASS)
    b.part(b.ellipse(16 + (1 if side else 0), cy - 5, 5.5, 5), MARBLE, sphere=(14, cy - 8, 6))
    for sx in ((-8, 7) if not side else (-6,)):
        b.part(b.ellipse(16 + sx + (0.5 if sx > 0 else 0), cy + 2 - bob, 2.2, 3.4), BRASS)
    if not back:
        ex = 16 + (3 if side else (1 if facing == "down_right" else 0))
        b.dot(ex, cy - 5, hex_color("#9cfff0"))
        b.dot(ex + 1, cy - 5, hex_color("#ffffff"))
        b.dot(ex, cy - 4, hex_color("#3fd6d0"))
    else:
        b.dot(16, cy - 6, BRASS[1])
    b.dot(16, cy + 10 + (frame % 2), hex_color("#9cfff0"))
    b.outline(hex_color("#22203a"))
    return b.canvas()


# --- Wind Spires: wisp and the Tempest Colossus ---------------------------------

WIND = r4("#ffffff", "#d8f4ff", "#94d0ec", "#4a8ab8")
STORM = r4("#eef2fc", "#b4bedc", "#7e88b0", "#4e5478")
SPARK = r4("#ffffff", "#fff6a8", "#ffd45c", "#d99a2e")


def wisp(facing: str, frame: int) -> Canvas:
    """Swirling wind spirit: a round head trailing a spiral tail."""
    b = Body(32)
    bob = [0, -1, -2, -1][frame]
    b.shadow(16, 28, 6, 1.6, 55)
    side = facing == "right"
    back = facing in ("up", "up_right")
    cy = 14 + bob
    tail_dir = -1 if side else 0
    for k in range(5):
        t = k / 4
        ang = frame * 0.9 + k * 1.2
        tx = 16 + tail_dir * k * 2.2 + math.cos(ang) * (3 - t * 2)
        ty = cy + 5 + k * 2.2
        b.part(b.ellipse(tx, ty, 3.4 - t * 2.2, 2.4 - t * 1.4), WIND)
    b.part(b.ellipse(16 + (1 if side else 0), cy, 6, 5.5), WIND, sphere=(14, cy - 3, 7))
    for k in range(3):
        ang = frame * 1.3 + k * 2.1
        b.dot(16 + math.cos(ang) * 9, cy + math.sin(ang) * 4, WIND[0])
    if not back:
        ex = 16 + (3 if side else (1 if facing == "down_right" else 0))
        for x in ([ex - 2, ex + 2] if not side else [ex + 1]):
            b.dot(x, cy - 1, hex_color("#2a4a7a"))
            b.dot(x, cy, hex_color("#2a4a7a"))
    b.outline(hex_color("#1e2a4a"))
    return b.canvas()


def tempest(facing: str, frame: int) -> Canvas:
    """Marble giant crowned with a storm cloud, a lightning core in its chest."""
    b = Body(48)
    bob = [0, -1, -1, 0][frame]
    b.shadow(24, 45, 15, 3.2, 90)
    side = facing == "right"
    back = facing in ("up", "up_right")
    cy = 27 + bob
    w = 9 if side else 12
    # Floating fists, a little apart from the body.
    for sx in ((-17, 17) if not side else (-12,)):
        fy = cy + 7 - (bob if sx > 0 else -bob)
        b.part(b.ellipse(24 + sx, fy, 5, 5.5), MARBLE, sphere=(22 + sx, fy - 3, 6))
        b.part(b.rect(24 + sx - 4, fy - 5, 24 + sx + 3, fy - 4), BRASS)
    # Tapering torso fading into a whirl of wind below.
    b.part(b.ellipse(24, cy + 1, w, 10), MARBLE, sphere=(20, cy - 5, 15))
    b.part(b.ellipse(24, cy + 11, w * 0.55, 5), MARBLE, sphere=(22, cy + 8, 8))
    for k in range(3):
        b.part(b.ellipse(24 + (k - 1) * 2 + math.sin(frame + k) * 1.5, cy + 16 + k * 2.5, 6 - k * 1.6, 1.4), WIND)
    # Brass pauldrons.
    for sx in ((-w + 1, w - 1) if not side else (-w + 2,)):
        b.part(b.ellipse(24 + sx, cy - 6, 4.5, 3.5), BRASS, sphere=(22 + sx, cy - 8, 5))
    b.part(b.rect(24 - w + 3, cy - 8, 24 + w - 4, cy - 6), BRASS)
    b.part(b.ellipse(24 + (2 if side else 0), cy - 11, 5.5, 5), MARBLE, sphere=(22, cy - 14, 6))
    # Storm-cloud crown: light tops, dark bellies.
    for k, (dx, dy, r) in enumerate(((-9, -20, 5), (0, -23, 6.5), (9, -20, 5), (-5, -18, 4), (5, -18, 4))):
        b.part(b.ellipse(24 + dx + math.sin(frame + k) * 0.8, cy + dy, r, r * 0.68), STORM, sphere=(20, cy - 26, 10))
    if not back:
        core_x = 24 + (3 if side else (2 if facing == "down_right" else 0))
        b.part(b.ellipse(core_x, cy + 1, 3.6, 4.2), SPARK, separate=False)
        b.dot(core_x - 1, cy, SPARK[0])
        eyes = [core_x - 3, core_x + 2] if not side else [core_x + 2]
        for ex in eyes:
            b.dot(ex, cy - 10, hex_color("#9cf0ff"))
            b.dot(ex + 1, cy - 10, hex_color("#ffffff"))
    else:
        b.part(b.rect(22, cy - 4, 25, cy + 8), BRASS)
    # Crackling bolts from the crown.
    if frame in (1, 3):
        x = 24 + (12 if frame == 1 else -13)
        for k in range(8):
            b.dot(x + (1 if k % 3 == 1 else 0) - (1 if k % 3 == 2 else 0), cy - 18 + k * 2, SPARK[0 if k % 2 else 1])
    b.outline(hex_color("#22203a"))
    return b.canvas()


# --- Misty Marsh: toad and the Bog King ---------------------------------------

TOAD = r4("#a8c86a", "#7a9e48", "#53743a", "#34502a")
BELLY = r4("#f0e8b8", "#d8c88a", "#b0a064", "#80723e")
CROWN = r4("#fff2a8", "#ffd45c", "#d99a2e", "#8a5a22")


def _toad_body(b: Body, facing: str, frame: int, cx: float, cy: float, scale: float, crown: bool) -> None:
    side = facing == "right"
    back = facing in ("up", "up_right")
    squash = [0, 1, 0, -1][frame] * scale * 0.6
    w, h = 8 * scale, 5.5 * scale - squash
    for sx in ((-w * 0.8, w * 0.8) if not side else (-w * 0.6, w * 0.6)):
        b.part(b.ellipse(cx + sx, cy + h * 0.7, 2.6 * scale, 1.8 * scale), TOAD)
    b.part(b.ellipse(cx, cy, w if not side else w * 0.85, h), TOAD, sphere=(cx - 2 * scale, cy - 3 * scale, w + 2))
    if not back:
        b.part(b.ellipse(cx + (2 * scale if side else 0), cy + h * 0.35, w * 0.55, h * 0.45), BELLY)
    eyes = [-0.55, 0.55] if not side else [0.35]
    for ex in eyes:
        x = cx + ex * w
        y = cy - h * 0.85
        b.part(b.ellipse(x, y, 2.2 * scale, 2.2 * scale), TOAD, sphere=(x - 1, y - 1, 3 * scale))
        if not back:
            b.dot(x + (0.5 if side else 0), y, hex_color("#1a1a10"))
            b.dot(x - 0.5, y - 0.8, hex_color("#ffffff"))
    if crown:
        top = cy - h - 2 * scale
        for k in range(5):
            x = cx - 4 * scale + k * 2 * scale
            b.part(b.rect(x - 1, top - (2 if k % 2 == 0 else 0), x + 1, top + 2), CROWN)


def toad(facing: str, frame: int) -> Canvas:
    b = Body(32)
    b.shadow(16, 27, 8, 1.8, 70)
    _toad_body(b, facing, frame, 16, 21 - [0, 0, -2, -1][frame], 1.0, False)
    b.outline(hex_color("#14200e"))
    return b.canvas()


def bog_king(facing: str, frame: int) -> Canvas:
    b = Body(48)
    b.shadow(24, 43, 15, 3, 90)
    _toad_body(b, facing, frame, 24, 32 - [0, 0, -1, 0][frame], 1.8, True)
    b.outline(hex_color("#14200e"))
    return b.canvas()
