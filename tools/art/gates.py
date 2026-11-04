"""Passages between lands, drawn in the pack's warm outlined style:
  gate_bridge_v  — wooden gateway with a little roof and lantern over a
                   bridge that leaves the island to the north or south;
  gate_bridge_h  — bridge anchor posts with ropes and a signpost (east/west);
  gate_cave_mouth / gate_cave_exit — rock arch, dark inside / bright daylight;
  gate_stairs_down / gate_stairs_up — ruin stairs into the dark / up to light."""
from __future__ import annotations

import numpy as np

from pixel import Canvas, hex_color, ramp

OUTLINE = hex_color("#2a1a1c")
WOOD = ramp("#e0ac72", "#b47c4a", "#87562f", "#5a3620")
ROOF = ramp("#e07a52", "#b8523a", "#863628")
ROPE = ramp("#f2e4bc", "#cdb88a")
STONE = ramp("#c8ccd4", "#9aa0ae", "#6e7486", "#4a4e60", "#33364a")
MOSS = ramp("#a6d46a", "#6aa848", "#3e7a3a")
LIGHT = hex_color("#ffe9a0")


def _outline(c: Canvas) -> None:
    solid = c.px[:, :, 3] == 255
    edge = np.zeros_like(solid)
    edge[1:, :] |= solid[:-1, :]
    edge[:-1, :] |= solid[1:, :]
    edge[:, 1:] |= solid[:, :-1]
    edge[:, :-1] |= solid[:, 1:]
    c.px[edge & ~solid] = OUTLINE


def _shadow(c: Canvas, cx: float, cy: float, rx: float, ry: float) -> None:
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                c.blend(x, y, (20, 16, 24, 80))


def _post(c: Canvas, x: int, top: int, bottom: int, width: int = 5) -> None:
    for y in range(top, bottom):
        for dx in range(width):
            c.put(x + dx, y, WOOD[0] if dx == 0 else (WOOD[1] if dx < width - 1 else WOOD[2]))
    c.hline(x, x + width - 1, top, WOOD[0])
    for y in range(top + 4, bottom - 2, 7):
        c.put(x + width // 2, y, WOOD[3])


def bridge_v() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(56, 64)
    _shadow(c, 28, 60, 25, 4)
    _post(c, 6, 18, 61, 6)
    _post(c, 44, 18, 61, 6)
    # Cross beam and little shingle roof.
    c.rect(3, 20, 50, 4, WOOD[1])
    c.hline(3, 52, 20, WOOD[0])
    c.hline(3, 52, 23, WOOD[3])
    for i, (a, b) in enumerate([(1, 54), (2, 53), (4, 51), (6, 49), (9, 46)]):
        c.hline(a, b, 18 - i * 2, ROOF[1] if i % 2 else ROOF[0])
        c.hline(a, b, 17 - i * 2, ROOF[2] if i % 2 else ROOF[1])
    c.hline(1, 54, 19, ROOF[2])
    # Sign board under the beam and a lantern.
    c.rect(18, 25, 20, 7, WOOD[0])
    c.rect(19, 26, 18, 5, WOOD[1])
    for x in range(22, 34, 3):
        c.hline(x, x + 1, 28, WOOD[3])
    c.vline(27, 24, 25, ROPE[1])
    c.vline(10, 24, 30, ROPE[1])
    c.rect(8, 30, 5, 6, WOOD[3])
    c.rect(9, 31, 3, 4, LIGHT)
    # Ropes hanging between the posts.
    for x in range(12, 44):
        sag = int(3 * np.sin((x - 12) / 32 * np.pi))
        c.put(x, 42 + sag, ROPE[0])
    _outline(c)
    return c, (28, 60)


def bridge_h() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(48, 60)
    _shadow(c, 24, 55, 20, 5)
    # Back post (higher) and front post (lower) with ropes running east.
    _post(c, 37, 12, 40, 4)
    for x in range(41, 48):
        c.put(x, 16 + (x - 41) // 4, ROPE[0])
    _post(c, 29, 30, 57, 5)
    for x in range(34, 48):
        c.put(x, 35 + (x - 34) // 4, ROPE[0])
    for y in range(17, 36):
        c.put(33 + (y - 17) * 4 // 19, y, ROPE[1])
    # Signpost with an arrow board pointing out to the sky.
    _post(c, 10, 18, 56, 4)
    for y in range(20, 29):
        half = 4 - abs(y - 24) if y in range(20, 29) else 0
        c.hline(4, 24 + max(0, 4 - abs(y - 24)), y, WOOD[1] if y < 24 else WOOD[2])
    c.hline(4, 26, 20, WOOD[0])
    for x in range(8, 22, 3):
        c.hline(x, x + 1, 24, WOOD[3])
    c.rect(8, 32, 5, 6, WOOD[3])
    c.rect(9, 33, 3, 4, LIGHT)
    _outline(c)
    return c, (24, 55)


def _arch(c: Canvas, cx: int, base: int, outer_rx: int, outer_h: int, inner_rx: int, inner_h: int, inside) -> None:
    rng = np.random.default_rng(7)
    for y in range(base - outer_h, base):
        for x in range(cx - outer_rx, cx + outer_rx + 1):
            nx = (x - cx) / outer_rx
            ny = (base - y) / outer_h
            if nx * nx + (ny ** 2.2) > 1.0:
                continue
            inx = (x - cx) / inner_rx
            iny = (base - y) / inner_h
            if inx * inx + (iny ** 2) <= 1.0:
                inside(c, x, y, iny)
                continue
            shade = 1 if x < cx - outer_rx // 3 else (2 if x < cx + outer_rx // 3 else 3)
            if (x * 7 + y * 13) % 11 == 0 or rng.random() < 0.06:
                shade = min(4, shade + 1)
            if y < base - outer_h + 4 or (ny > 0.8 and (x + y) % 3 == 0):
                shade = max(0, shade - 1)
            c.put(x, y, STONE[shade])
    # Moss over the top and a few stones at the foot.
    for x in range(cx - outer_rx + 2, cx + outer_rx - 1):
        nx = (x - cx) / outer_rx
        top = base - int(outer_h * max(0.0, 1 - nx * nx) ** (1 / 2.2))
        for k in range(0, 2 + (x % 3 == 0)):
            c.put(x, top + k, MOSS[1] if k == 0 else MOSS[2])
        if x % 5 == 0:
            c.put(x, top - 1, MOSS[0])


def cave(exit_light: bool) -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(72, 58)
    _shadow(c, 36, 55, 32, 4)

    def dark(cv: Canvas, x: int, y: int, depth: float) -> None:
        cv.put(x, y, hex_color("#0e0a16") if depth < 0.7 else hex_color("#1c1626"))

    def bright(cv: Canvas, x: int, y: int, depth: float) -> None:
        tone = ramp("#fffaf0", "#e6f4ff", "#b8dcf8", "#86b4e0")
        cv.put(x, y, tone[min(3, int(depth * 3.2))])

    _arch(c, 36, 56, 34, 52, 17, 36, bright if exit_light else dark)
    crystal = ramp("#e8fbff", "#8ee6ff", "#3a9ad8")
    for x, y, hgt in ((8, 52, 7), (13, 54, 5), (60, 53, 8), (65, 55, 4)):
        for i in range(hgt):
            w = max(0, (hgt - i) // 3)
            c.hline(x - w, x + w, y - i, crystal[1] if i < hgt - 2 else crystal[0])
        c.put(x + 1, y - 1, crystal[2])
    if exit_light:
        for i in range(10):
            c.blend(36 - 6 + i, 52, (255, 250, 220, 120))
    _outline(c)
    return c, (36, 55)


def stairs(down: bool) -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(60, 56)
    _shadow(c, 30, 52, 28, 4)
    # Two carved pillars with a lintel.
    for px in (4, 46):
        c.rect(px, 8, 10, 45, STONE[2])
        c.vline(px, 8, 52, STONE[1])
        c.vline(px + 9, 8, 52, STONE[3])
        c.rect(px - 1, 6, 12, 3, STONE[1])
        c.rect(px - 1, 49, 12, 4, STONE[3])
    c.rect(2, 4, 56, 6, STONE[1])
    c.hline(2, 57, 4, STONE[0])
    c.hline(2, 57, 9, STONE[3])
    for x in range(8, 52, 6):
        c.put(x, 6, STONE[3])
    # Steps between the pillars.
    for i in range(7):
        y = 48 - i * 5 if not down else 14 + i * 5
        tone = 4 - min(4, i * 4 // 6) if down else 1 + min(3, i // 2)
        if down:
            shade = STONE[min(4, 1 + i // 2)]
            gap = hex_color("#120e18") if i > 3 else STONE[4]
        else:
            shade = STONE[max(0, 3 - i // 2)]
            gap = STONE[3]
        c.rect(14, y, 32, 4, shade)
        c.hline(14, 45, y + 4, gap)
    if down:
        c.rect(14, 10, 32, 6, hex_color("#120e18"))
    else:
        for y in range(10, 20):
            c.hline(14, 45, y, ramp("#fffaf0", "#ffe9b0", "#f0c878")[min(2, (y - 10) // 4)])
    # Cracks and moss.
    c.vline(8, 20, 26, STONE[3])
    c.vline(50, 30, 35, STONE[3])
    for x in range(2, 58, 4):
        c.put(x, 3, MOSS[1])
    _outline(c)
    return c, (30, 52)


def build() -> dict[str, tuple[Canvas, tuple[int, int]]]:
    return {
        "gate_bridge_v": bridge_v(),
        "gate_bridge_h": bridge_h(),
        "gate_cave_mouth": cave(False),
        "gate_cave_exit": cave(True),
        "gate_stairs_down": stairs(True),
        "gate_stairs_up": stairs(False),
        "lever_off": lever(False),
        "lever_on": lever(True),
        "vent_idle": vent(False),
        "vent_active": vent(True),
    }


def lever(on: bool) -> tuple[Canvas, tuple[int, int]]:
    """Dungeon lever: stone socket, iron handle, a gem that turns green."""
    c = Canvas(22, 28)
    _shadow(c, 11, 25, 9, 2.5)
    c.rect(4, 16, 14, 9, STONE[2])
    c.hline(4, 17, 16, STONE[1])
    c.hline(4, 17, 24, STONE[3])
    c.rect(8, 18, 6, 3, STONE[4])
    iron = ramp("#d8dee6", "#9aa4b2", "#5c6676")
    for i in range(12):
        x = 11 + (i // 2 if on else -i // 2)
        c.put(x, 18 - i, iron[1])
        c.put(x + 1, 18 - i, iron[2])
    knob_x = 11 + (6 if on else -6)
    c.ellipse(knob_x + 0.5, 6.5, 2.6, 2.6, WOOD[1])
    c.put(knob_x, 5, WOOD[0])
    gem = hex_color("#5aff7a") if on else hex_color("#ff5a3a")
    c.rect(10, 21, 2, 2, gem)
    _outline(c)
    return c, (11, 25)


def vent(active: bool) -> tuple[Canvas, tuple[int, int]]:
    """Floor vent: iron grate over embers (the flame itself is drawn live)."""
    c = Canvas(20, 14)
    iron = ramp("#5c5056", "#3a3036", "#221a1e")
    c.ellipse(10, 7, 9, 5, iron[1])
    c.ellipse(10, 7, 6.5, 3.4, hex_color("#ff8a2a") if active else hex_color("#6a1e0c"))
    for x in (6, 9, 12, 15):
        c.vline(x, 4, 10, iron[0])
    c.hline(3, 17, 7, iron[2])
    _outline(c)
    return c, (10, 7)
