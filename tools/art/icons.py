"""16x16 inventory icons for every item in data/equipment.json."""
from __future__ import annotations

from pixel import Canvas, hex_color, ramp

OUT = hex_color("#241a30")
WOOD = ramp("#e3b070", "#b3824f", "#81573d", "#523224")
GOLD = ramp("#fff6c0", "#ffd45c", "#e0962e", "#8a4a22")
IRON = ramp("#eef2f2", "#b9c2c8", "#7f899a", "#4f5866")
FUR = ramp("#e4ebf5", "#a8b4cc", "#6d7a9c", "#46506e")
LEATHER = ramp("#d6a06a", "#a8703f", "#7a4c2e", "#523224")


def _finish(c: Canvas) -> Canvas:
    c.outline(OUT)
    return c


def staff(head) -> Canvas:
    c = Canvas(16, 16)
    for i in range(10):
        x, y = 3 + i, 13 - i
        c.put(x, y, WOOD[1])
        c.put(x + 1, y, WOOD[2])
    c.ellipse(12.5, 3.5, 2.6, 2.6, head[1])
    c.put(12, 2, head[0])
    c.put(11, 3, head[0])
    return _finish(c)


def iron_staff() -> Canvas:
    c = staff(ramp("#c6f4ff", "#7fd4ff", "#3a8fe0"))
    for x, y in ((6, 10), (7, 9), (9, 7), (10, 6)):
        c.put(x, y, IRON[1])
        c.put(x + 1, y, IRON[2])
    return c


def armor(base, trim) -> Canvas:
    c = Canvas(16, 16)
    for y in range(3, 14):
        half = 6 if y > 4 else 4
        for x in range(8 - half, 8 + half):
            if y < 6 and 6 <= x <= 9:
                continue  # neck opening
            color = base[0] if x < 6 else (base[1] if x < 11 else base[2])
            c.put(x, y, color)
    c.hline(3, 12, 9, trim[1])
    c.put(8, 9, trim[0])
    return _finish(c)


def mantle(fur, clasp) -> Canvas:
    c = Canvas(16, 16)
    for y in range(3, 14):
        spread = 3 + (y - 3) // 2
        for x in range(8 - spread, 8 + spread):
            c.put(x, y, fur[0] if x < 7 else (fur[1] if x < 10 else fur[2]))
    for x in range(3, 13, 2):
        c.put(x, 13, fur[2])
    c.hline(5, 10, 4, fur[0])
    c.rect(7, 5, 2, 2, clasp)
    return _finish(c)


def amulet() -> Canvas:
    c = Canvas(16, 16)
    for x in range(3, 13):
        y = 2 + abs(x - 8) // 2
        c.put(x, 7 - y + 2, GOLD[2])
    c.ellipse(8, 10, 3.6, 3.6, GOLD[1])
    c.ellipse(8, 10, 2.2, 2.2, hex_color("#5aaaf0"))
    c.put(7, 9, hex_color("#c6ecff"))
    return _finish(c)


def gem(colors) -> Canvas:
    c = Canvas(16, 16)
    rows = [(6, 9), (4, 11), (3, 12), (3, 12), (4, 11), (5, 10), (6, 9), (7, 8)]
    for i, (a, b) in enumerate(rows):
        y = 4 + i
        for x in range(a, b + 1):
            level = 0 if (x < 7 and i < 3) else (1 if x < 10 else 2)
            c.put(x, y, colors[level])
    c.put(6, 5, hex_color("#ffffff"))
    for x, y in ((2, 3), (13, 4), (12, 13)):
        c.put(x, y, colors[0])
    return _finish(c)


def potion(colors) -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 10, 4.6, 4.2, colors[1])
    for y in range(7, 15):
        for x in range(3, 13):
            if c.alpha(x, y) and (x > 9 or y > 12):
                c.put(x, y, colors[2])
    c.rect(7, 3, 3, 3, hex_color("#d6e6f0"))
    c.rect(7, 2, 3, 1, WOOD[1])
    c.put(6, 8, hex_color("#ffffff"))
    c.put(6, 9, colors[0])
    return _finish(c)


def essence() -> Canvas:
    c = Canvas(16, 16)
    star = ramp("#ffffff", "#fff2a8", "#c9a2ff")
    for i in range(-5, 6):
        c.put(8 + i, 8, star[1] if abs(i) < 3 else star[2])
        c.put(8, 8 + i, star[1] if abs(i) < 3 else star[2])
    for i in range(-2, 3):
        c.put(8 + i, 8 + i, star[1])
        c.put(8 + i, 8 - i, star[1])
    c.put(8, 8, star[0])
    return _finish(c)


def relic() -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 8, 5.5, 5.5, GOLD[1])
    c.ellipse(8, 8, 3.6, 3.6, GOLD[2])
    c.ellipse(8, 8, 2.2, 2.2, hex_color("#5fd6ff"))
    c.put(7, 7, hex_color("#ffffff"))
    for x, y in ((8, 2), (14, 8), (8, 14), (2, 8)):
        c.put(x, y, GOLD[0])
    return _finish(c)


def pelt() -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 9, 6, 4.2, FUR[1])
    for x in range(3, 14):
        c.put(x, 7, FUR[0] if x % 3 else FUR[1])
        c.put(x, 11, FUR[2])
    c.hline(5, 11, 9, LEATHER[1])
    return _finish(c)


def ore() -> Canvas:
    c = Canvas(16, 16)
    stone = ramp("#a9b3bd", "#7f899a", "#5a6074")
    c.ellipse(8, 9, 5.5, 4.6, stone[1])
    for y in range(5, 14):
        for x in range(2, 14):
            if c.alpha(x, y) and (x < 6 and y < 9):
                c.put(x, y, stone[0])
            elif c.alpha(x, y) and (x > 10 or y > 11):
                c.put(x, y, stone[2])
    for x, y in ((6, 8), (9, 7), (10, 10), (7, 11)):
        c.put(x, y, hex_color("#e8a05a"))
        c.put(x, y - 1, hex_color("#ffe0a8"))
    return _finish(c)


def build() -> dict[str, Canvas]:
    return {
        "apprentice_staff": staff(ramp("#c8f0a0", "#7fcf6a", "#3f8f5a")),
        "ironbound_staff": iron_staff(),
        "leather_armor": armor(LEATHER, GOLD),
        "wolfskin_mantle": mantle(FUR, LEATHER[1]),
        "reinforced_wolf_mantle": mantle(FUR, IRON[1]),
        "mana_amulet": amulet(),
        "pyromancer_core": gem(ramp("#ffe066", "#ff9a3c", "#c8352e")),
        "frost_heart": gem(ramp("#e8fbff", "#7fd4ff", "#3a6fc0")),
        "storm_eye": gem(ramp("#f2e6ff", "#b48aff", "#6a4ac8")),
        "health_potion": potion(ramp("#ffb0b8", "#f05a6a", "#b8303f")),
        "mana_potion": potion(ramp("#c6ecff", "#5aaaf0", "#2f6ec0")),
        "starlight_essence": essence(),
        "ancient_relic": relic(),
        "wolf_pelt": pelt(),
        "iron_ore": ore(),
    }
