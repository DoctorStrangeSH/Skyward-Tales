"""Treasure chests in three tiers (wood, iron, gold) and loot piles, drawn in
the purchased pack's warm style: soft dark-brown outline, plank shading,
metal bands with rivets, a lock plate. Open chests show a glowing hoard."""
from __future__ import annotations

from pixel import Canvas, hex_color, ramp

OUTLINE = hex_color("#2a1a1c")

TIERS = {
    # wood: light, highlight, mid, dark ; band: light, mid, dark ; gem
    "wood": (ramp("#e6b47a", "#c08850", "#93603a", "#5e3a26"), ramp("#b8a088", "#7d6a58", "#4e4038"), None),
    "iron": (ramp("#b98a60", "#8a5e3e", "#6a432c", "#42281c"), ramp("#e6eef4", "#9eadbc", "#5c6a7c"), "#7fd4ff"),
    "gold": (ramp("#7aa0c8", "#4f78a8", "#355680", "#1f3456"), ramp("#fff2a8", "#f0b840", "#a8641e"), "#ff5a6a"),
}


def _shadow(c: Canvas, cx: float, cy: float, rx: float, ry: float) -> None:
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                c.blend(x, y, (20, 16, 24, 90))


def _outline(c: Canvas) -> None:
    import numpy as np
    alpha = c.px[:, :, 3]
    solid = alpha == 255
    edge = np.zeros_like(solid)
    edge[1:, :] |= solid[:-1, :]
    edge[:-1, :] |= solid[1:, :]
    edge[:, 1:] |= solid[:, :-1]
    edge[:, :-1] |= solid[:, 1:]
    edge &= ~solid
    c.px[edge] = OUTLINE


def chest(tier: str, opened: bool) -> tuple[Canvas, tuple[int, int]]:
    wood, band, gem = TIERS[tier]
    w, h = 28, 28
    c = Canvas(w, h)
    _shadow(c, 14, 24, 12, 3)
    x0, x1 = 3, 24          # body columns (inclusive)
    body_top, body_bottom = 14, 23
    # Body planks: vertical boards, light left, dark right, darker bottom.
    for y in range(body_top, body_bottom + 1):
        for x in range(x0, x1 + 1):
            shade = 1 if x < 9 else (2 if x < 20 else 3)
            if y == body_bottom:
                shade = 3
            if (x - x0) % 5 == 4:
                shade = min(3, shade + 1)   # plank seams
            c.put(x, y, wood[shade])
    c.hline(x0, x1, body_top, wood[0])
    # Metal bands and corner rivets.
    for bx in (x0 + 3, x1 - 3):
        c.vline(bx, body_top, body_bottom, band[1])
        c.vline(bx + 1, body_top, body_bottom, band[2])
        c.put(bx, body_top + 2, band[0])
        c.put(bx, body_bottom - 1, band[0])
    c.hline(x0, x1, body_bottom - 1, band[2])
    if opened:
        # Lid swung back: its inner face above the body, then the hoard.
        for y in range(4, 10):
            for x in range(x0 + 1, x1):
                c.put(x, y, wood[3] if y > 5 else wood[2])
        c.hline(x0 + 1, x1 - 1, 4, wood[1])
        for bx in (x0 + 3, x1 - 3):
            c.vline(bx, 4, 9, band[2])
        # Interior rim and glowing coins.
        c.rect(x0 + 1, 10, x1 - x0 - 1, 4, hex_color("#2a1a22"))
        coin = ramp("#fffbe0", "#ffd45c", "#c88a2a")
        for x in range(x0 + 2, x1 - 1):
            top = 11 - (1 if 8 < x < 19 else 0) - (1 if 11 < x < 16 else 0)
            for y in range(top, 14):
                c.put(x, y, coin[1] if (x + y) % 3 else coin[2])
            c.put(x, top, coin[0] if x % 2 else coin[1])
        if gem:
            c.put(13, 10, hex_color(gem))
            c.put(14, 10, hex_color("#ffffff"))
    else:
        # Domed lid: rounded top, highlight band, lock plate.
        lid_top = 6
        for y in range(lid_top, body_top):
            inset = 2 if y == lid_top else (1 if y == lid_top + 1 else 0)
            for x in range(x0 + inset, x1 + 1 - inset):
                shade = 0 if y < lid_top + 3 else 1
                if x > 19:
                    shade = 2
                c.put(x, y, wood[shade])
        c.hline(x0 + 2, x1 - 2, lid_top + 1, wood[0])
        c.hline(x0, x1, body_top - 1, wood[3])
        for bx in (x0 + 3, x1 - 3):
            c.vline(bx, lid_top + 1, body_top - 1, band[1])
            c.vline(bx + 1, lid_top + 1, body_top - 1, band[2])
            c.put(bx, lid_top + 1, band[0])
        # Lock plate over the seam.
        c.rect(12, body_top - 3, 4, 6, band[1])
        c.vline(12, body_top - 3, body_top + 2, band[0])
        c.vline(15, body_top - 3, body_top + 2, band[2])
        c.put(13, body_top, OUTLINE)
        c.put(14, body_top, OUTLINE)
        c.put(13, body_top + 1, OUTLINE)
        if gem:
            c.put(13, body_top - 2, hex_color(gem))
            c.put(14, body_top - 2, hex_color("#ffffff"))
    _outline(c)
    return c, (14, 24)


def coins() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(14, 12)
    _shadow(c, 7, 10, 6, 1.6)
    coin = ramp("#fffbe0", "#ffd45c", "#e09a2e", "#a8641e")
    for cx, cy in ((4, 7), (9, 7), (6, 5), (7, 8)):
        c.ellipse(cx, cy, 2.6, 1.8, coin[2])
        c.ellipse(cx - 0.3, cy - 0.4, 1.8, 1.1, coin[1])
        c.put(int(cx) - 1, int(cy) - 1, coin[0])
    _outline(c)
    return c, (7, 10)


def build() -> dict[str, tuple[Canvas, tuple[int, int]]]:
    result = {"loot_coins": coins()}
    for tier in TIERS:
        result[f"chest_{tier}_closed"] = chest(tier, False)
        result[f"chest_{tier}_open"] = chest(tier, True)
    return result
