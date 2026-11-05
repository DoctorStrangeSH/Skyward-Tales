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


def lens() -> Canvas:
    c = Canvas(16, 16)
    for x in range(3, 13):
        c.put(x, 3 + abs(x - 8) // 3, GOLD[2])
    c.ellipse(8, 10, 4, 4, GOLD[1])
    for y in range(7, 14):
        for x in range(5, 12):
            if ((x - 8) / 2.6) ** 2 + ((y - 10) / 2.6) ** 2 <= 1:
                c.put(x, y, hex_color("#d0b8ff") if x < 8 else hex_color("#9a7aff"))
    c.put(7, 9, hex_color("#ffffff"))
    return _finish(c)


def pattern_key() -> Canvas:
    c = Canvas(16, 16)
    glow = ramp("#f6f0ff", "#c9b0ff", "#8a6ae8")
    c.ellipse(5, 5, 3.5, 3.5, GOLD[1])
    c.ellipse(5, 5, 1.6, 1.6, glow[1])
    for i in range(8):
        c.put(7 + i, 7 + i, GOLD[1])
        c.put(8 + i, 7 + i, GOLD[2])
    for x, y in ((11, 13), (13, 11), (12, 14)):
        c.put(x, y, GOLD[1])
    c.put(4, 4, hex_color("#ffffff"))
    return _finish(c)


def build() -> dict[str, Canvas]:
    return {
        "apprentice_staff": staff(ramp("#c8f0a0", "#7fcf6a", "#3f8f5a")),
        "hunting_bow": bow(ramp("#d8a868", "#a06a3a", "#5a3a20")),
        "elm_longbow": bow(ramp("#e8c890", "#8a5a30", "#4a2e18"), tip="#c0c8d0"),
        "wind_bow": bow(ramp("#e0f8ff", "#6ab0d8", "#2e5a88"), string="#ffffff", tip="#ffe066"),
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
        "crystal_lens": lens(),
        "pattern_key": pattern_key(),
        "sky_seal": essence(),
        "wood": log_icon(), "stone": stone_icon(), "fish": fish_icon(),
        "healroot": flower_icon(ramp("#ffd0c0", "#e05a4a", "#a8302a")), "bluebell": flower_icon(ramp("#e0f0ff", "#5a8ae0", "#2a4aa0")),
        "fish_stew": bowl_icon(ramp("#ffe0a0", "#e0a040", "#a06020")), "herb_tea": bowl_icon(ramp("#d8ffd0", "#7ac060", "#3a7a30")),
        "hearty_stew": bowl_icon(ramp("#ffc090", "#c86030", "#803020")),
        "power_elixir": potion(ramp("#ffe0a0", "#ff9a3c", "#c8352e")), "swift_tonic": potion(ramp("#e0fff0", "#60e0b0", "#2a9a7a")),
        "steel_staff": staff(ramp("#e8eef4", "#a8b4c4", "#6a7a90")),
        "skysteel_staff": staff(ramp("#fff6c8", "#9cf0ff", "#3a8fe0")),
        "steel_mail": armor(ramp("#d8dce4", "#9aa2b0", "#5e6676"), ramp("#f4f4f8", "#c8ccd4", "#8a909c")),
        "skysteel_mail": armor(ramp("#e8f8ff", "#8ad0f0", "#3a7ab0"), GOLD),
        "recipe_steel_mail": scroll_icon(), "recipe_skysteel": scroll_icon(), "coal_sack": stone_icon(),
        "recipe_hearty_stew": scroll_icon(), "recipe_power_elixir": scroll_icon(), "recipe_swift_tonic": scroll_icon(),
        **build_combat(),
        **build_materials(),
        **build_fish(),
        **build_ash(),
    }


def log_icon() -> Canvas:
    c = Canvas(16, 16)
    bark = ramp("#b9875a", "#744d33", "#442d31")
    for y in range(6, 12):
        c.hline(2, 12, y, bark[1] if y not in (6, 11) else bark[2])
    c.ellipse(13, 8.5, 2.2, 3, bark[0])
    c.put(13, 8, bark[2])
    c.outline(hex_color("#302423"))
    return c


def stone_icon() -> Canvas:
    c = Canvas(16, 16)
    st = ramp("#b8b49c", "#7b7765", "#544e45")
    c.ellipse(8, 9, 5.5, 4.5, st[1])
    c.ellipse(6.5, 7.5, 2.5, 2, st[0])
    c.outline(hex_color("#302423"))
    return c


def fish_icon(sc=None, long: float = 4.5, stripes=None) -> Canvas:
    c = Canvas(16, 16)
    sc = sc or ramp("#d8f0ff", "#7ab0d8", "#3a6a98")
    c.ellipse(7, 8, long, 2.6, sc[1])
    if stripes:
        for x in (6, 8, 10):
            c.vline(x, 6, 10, hex_color(stripes))
    c.hline(4, 9, 7, sc[0])
    for k in range(3):
        c.vline(12 + k, 8 - k - 1, 8 + k + 1, sc[2])
    c.put(4, 7, hex_color("#1a1a2a"))
    c.outline(hex_color("#302423"))
    return c


def flower_icon(colors) -> Canvas:
    c = Canvas(16, 16)
    c.vline(8, 7, 14, ramp("#6c9a50", "#4a7a42", "#335c38")[1])
    c.put(6, 12, hex_color("#6c9a50"))
    c.put(10, 11, hex_color("#6c9a50"))
    c.ellipse(8, 5, 3, 2.6, colors[1])
    c.put(8, 5, colors[0])
    c.outline(hex_color("#302423"))
    return c


def bowl_icon(colors) -> Canvas:
    c = Canvas(16, 16)
    wood = ramp("#b9875a", "#744d33", "#442d31")
    for y in range(8, 13):
        half = 6 - (y - 8)
        c.hline(8 - half, 7 + half, y, wood[1])
    c.hline(2, 13, 8, colors[1])
    c.hline(3, 12, 7, colors[0])
    c.put(5, 4, hex_color("#ffffff"))
    c.put(9, 3, hex_color("#ffffff"))
    c.outline(hex_color("#302423"))
    return c


def scroll_icon() -> Canvas:
    c = Canvas(16, 16)
    paper = ramp("#fff6d8", "#e8d4a0", "#b89a60")
    c.rect(3, 4, 10, 8, paper[0])
    c.vline(3, 3, 12, paper[2])
    c.vline(12, 3, 12, paper[2])
    for y in (6, 8, 10):
        c.hline(5, 10, y, paper[2])
    c.put(10, 11, hex_color("#e05a4a"))
    c.outline(hex_color("#302423"))
    return c


# --- Swords and skill icons ---------------------------------------------------

def sword(blade, hilt=None, gem_color=None) -> Canvas:
    c = Canvas(16, 16)
    hilt = hilt or LEATHER
    for i in range(9):
        x, y = 5 + i, 10 - i
        c.put(x, y, blade[0])
        c.put(x + 1, y, blade[1])
        c.put(x, y + 1, blade[2])
    c.put(14, 1, blade[0])
    for i in range(-2, 3):
        c.put(5 + i, 10 + i, GOLD[1] if i else GOLD[0])
    for i in range(3):
        c.put(3 - i, 12 + i, hilt[1])
        c.put(4 - i, 12 + i, hilt[2])
    c.put(1, 14, GOLD[1])
    if gem_color:
        c.put(5, 10, hex_color(gem_color))
    return _finish(c)


def bow(wood, string="#e8e0d0", tip=None) -> Canvas:
    """A recurve bow, diagonal, with its string."""
    c = Canvas(16, 16)
    import math
    for i in range(24):
        t = i / 23.0
        # Curve from top-right to bottom-left, bulging up-left.
        x = 13 - 11 * t - math.sin(t * math.pi) * 3.2
        y = 2 + 11 * t - math.sin(t * math.pi) * 3.2
        c.put(int(round(x)), int(round(y)), wood[1])
        c.put(int(round(x)) + 1, int(round(y)), wood[2])
    for i in range(12):
        c.put(13 - i, 2 + i, hex_color(string))
    c.put(13, 1, wood[0]); c.put(1, 13, wood[0])
    if tip:
        c.put(13, 2, hex_color(tip)); c.put(2, 13, hex_color(tip))
    return _finish(c)


def _sky_bg(c: Canvas, colors) -> None:
    """Round badge behind a skill symbol so skills read apart from items."""
    c.ellipse(7.5, 7.5, 7.2, 7.2, colors[2])
    c.ellipse(7.0, 7.0, 6.0, 6.0, colors[1])


def skill_icon(kind: str) -> Canvas:
    c = Canvas(16, 16)
    white = hex_color("#ffffff")
    if kind == "lunge":
        _sky_bg(c, ramp("#fff0c0", "#d08a3a", "#7a3e20"))
        for i in range(10):
            c.put(2 + i, 8, white if i > 4 else hex_color("#ffe0a0"))
        for i in range(3):
            c.put(11 + i, 8 - i + 1, white)
            c.put(11 + i, 8 + i - 1, white)
        c.hline(2, 6, 5, hex_color("#ffd090"))
        c.hline(2, 6, 11, hex_color("#ffd090"))
    elif kind == "shockwave":
        _sky_bg(c, ramp("#f0e0c0", "#9a7a50", "#4e3a28"))
        c.vline(7, 2, 9, white)
        c.vline(8, 2, 9, hex_color("#c8d0d8"))
        c.hline(5, 10, 9, GOLD[1])
        for x in range(2, 14):
            c.put(x, 12 - (1 if x in (4, 11) else 0), hex_color("#ffe0a0"))
        for x, y in ((3, 10), (12, 10), (2, 13), (13, 13)):
            c.put(x, y, white)
    elif kind == "war_cry":
        _sky_bg(c, ramp("#ffd0b0", "#c8402e", "#6a1e1e"))
        for y, (a, b) in enumerate([(5, 6), (4, 8), (4, 9), (4, 9), (4, 8), (5, 6)]):
            c.hline(a, b, 5 + y, white)
        for i in range(3):
            c.put(10 + i, 4 + i * 3, hex_color("#ffe060"))
            c.put(11 + i, 4 + i * 3, hex_color("#ffe060"))
    elif kind == "blade_wave":
        _sky_bg(c, ramp("#e0f8ff", "#3a8ac0", "#1e3a6a"))
        for y in range(3, 13):
            dx = int(round(((y - 8) / 5.0) ** 2 * 4))
            c.put(9 - dx, y, white)
            c.put(8 - dx, y, hex_color("#bfefff"))
        c.hline(2, 5, 8, hex_color("#9fdfff"))
    elif kind == "volley":
        _sky_bg(c, ramp("#fff0c0", "#6a9a4a", "#2e4a20"))
        for dx in (-3, 0, 3):
            for i in range(7):
                c.put(5 + i + dx // 2, 11 - i + dx, white)
            c.put(12 + dx // 2, 4 + dx, GOLD[0])
    elif kind == "snare":
        _sky_bg(c, ramp("#e0e0e0", "#7a7a80", "#3a3a40"))
        for x in range(3, 13):
            c.put(x, 11, hex_color("#c8ccd4"))
        for x in range(4, 13, 2):
            c.put(x, 10, white)
            c.put(x - 1, 9, hex_color("#c8ccd4"))
        c.ellipse(7.5, 11.0, 2.0, 1.0, hex_color("#8a6a40"))
    elif kind == "imbue":
        _sky_bg(c, ramp("#f0e0ff", "#7a4ab8", "#2e1e50"))
        for i in range(10):
            c.put(3 + i, 12 - i, white)
            c.put(4 + i, 12 - i, hex_color("#c8d0d8"))
        c.hline(2, 6, 11, GOLD[1])
        for x, y, col in ((9, 3, "#ff9a3a"), (12, 6, "#7ad0ff"), (11, 2, "#d8b8ff"), (13, 4, "#ffe066")):
            c.put(x, y, hex_color(col))
    elif kind == "slash":
        _sky_bg(c, ramp("#f8f0e0", "#8a7a6a", "#3e3430"))
        for i in range(9):
            c.put(3 + i, 12 - i, white)
            c.put(4 + i, 12 - i, hex_color("#c8d0d8"))
    elif kind == "dodge":
        _sky_bg(c, ramp("#e0fff8", "#3aa08a", "#1e5048"))
        for i, w in enumerate([2, 4, 6, 7, 6]):
            c.hline(4, 4 + w, 4 + i * 2, white if i % 2 == 0 else hex_color("#bff0e0"))
    elif kind in ("fireball", "frostbolt", "chain_lightning"):
        colors = {"fireball": ramp("#ffe066", "#ff7a2c", "#8a2a1e"),
                  "frostbolt": ramp("#e8fbff", "#5ab0f0", "#1e3e80"),
                  "chain_lightning": ramp("#f2e6ff", "#9a6aff", "#3e2a80")}[kind]
        _sky_bg(c, ramp("#40384e", "#2a2438", "#18141f"))
        if kind == "fireball":
            c.ellipse(8, 9, 3.5, 3.5, colors[1])
            c.ellipse(8, 9.5, 2.0, 2.0, colors[0])
            for x, y in ((7, 4), (9, 3), (6, 5), (10, 5), (8, 5)):
                c.put(x, y, colors[1])
        elif kind == "frostbolt":
            for i in range(-4, 5):
                c.put(8 + i, 8, colors[0] if abs(i) < 2 else colors[1])
                c.put(8, 8 + i, colors[0] if abs(i) < 2 else colors[1])
                if abs(i) < 3:
                    c.put(8 + i, 8 + i, colors[1])
                    c.put(8 + i, 8 - i, colors[1])
        else:
            for x, y in ((9, 2), (8, 3), (7, 4), (6, 5), (7, 6), (8, 6), (9, 6), (8, 7), (7, 8), (6, 9), (7, 10), (8, 10), (7, 11), (6, 12), (5, 13)):
                c.put(x, y, colors[0])
                c.put(x + 1, y, colors[1])
    # Passives: a square frame instead of a round badge.
    elif kind in PASSIVE_SYMBOLS:
        frame = ramp("#e8d8b0", "#6a5038", "#3a2a20")
        c.rect(1, 1, 14, 14, frame[2])
        c.rect(2, 2, 12, 12, frame[1])
        PASSIVE_SYMBOLS[kind](c)
    return _finish(c)


def _p_steady(c: Canvas) -> None:
    for i in range(8):
        c.put(4 + i, 11 - i, hex_color("#eef2f2"))
    c.hline(3, 7, 10, GOLD[1])


def _p_tough(c: Canvas) -> None:
    for y in range(4, 12):
        half = 4 if y < 9 else 4 - (y - 8)
        c.hline(8 - half, 7 + half, y, IRON[1] if y < 8 else IRON[2])
    c.vline(7, 4, 11, IRON[0])


def _p_eye(c: Canvas) -> None:
    c.ellipse(7.5, 8, 4.5, 2.4, hex_color("#ffffff"))
    c.ellipse(7.5, 8, 1.8, 1.8, hex_color("#3a8ac0"))
    c.put(7, 7, hex_color("#ffffff"))


def _p_fleet(c: Canvas) -> None:
    c.rect(5, 5, 3, 5, LEATHER[1])
    c.rect(5, 9, 6, 2, LEATHER[2])
    for y in (5, 7):
        c.hline(9, 11, y, hex_color("#bff0e0"))


def _p_life(c: Canvas) -> None:
    red = ramp("#ffb0b8", "#e04a5a", "#a02a3a")
    c.ellipse(6, 7, 2.2, 2.2, red[1])
    c.ellipse(9.5, 7, 2.2, 2.2, red[1])
    for y in range(8, 12):
        c.hline(4 + (y - 8), 11 - (y - 8), y, red[1])
    c.put(5, 6, red[0])


def _p_treasure(c: Canvas) -> None:
    c.ellipse(7.5, 8, 4, 4, GOLD[1])
    c.ellipse(7.5, 8, 2.6, 2.6, GOLD[2])
    c.vline(7, 6, 10, GOLD[0])


PASSIVE_SYMBOLS = {"steady_hand": _p_steady, "toughness": _p_tough, "keen_eye": _p_eye,
                   "fleet": _p_fleet, "lifeblood": _p_life, "treasure_sense": _p_treasure}


def build_combat() -> dict[str, Canvas]:
    result = {
        "traveler_sword": sword(IRON),
        "iron_sword": sword(ramp("#dfe6ea", "#a3adb6", "#6a7480")),
        "steel_sword": sword(ramp("#f4f8fc", "#c0ccd8", "#7a8aa0"), gem_color="#5aaaf0"),
        "skysteel_blade": sword(ramp("#ffffff", "#9cf0ff", "#3a8fe0"), GOLD, "#ffe066"),
        "skyclaw_blade": sword(ramp("#ffffff", "#c8d4e8", "#4a5068"), GOLD, "#9ef0ff"),
    }
    for kind in ["lunge", "shockwave", "war_cry", "blade_wave", "imbue", "volley", "snare", "slash", "dodge", "fireball", "frostbolt", "chain_lightning", *PASSIVE_SYMBOLS]:
        result[f"skill_{kind}"] = skill_icon(kind)
    return result


# --- Monster materials and handcrafted gear ------------------------------------

def blob(colors) -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 10, 5, 3.6, colors[1])
    c.ellipse(7, 8.5, 3, 2.4, colors[0])
    c.put(6, 7, hex_color("#ffffff"))
    c.put(12, 12, colors[2])
    c.put(4, 12, colors[2])
    return _finish(c)


def fang() -> Canvas:
    c = Canvas(16, 16)
    bone = ramp("#fffaf0", "#e8dcc0", "#b8a888")
    for y in range(3, 14):
        half = max(0, (13 - y) // 3)
        for x in range(8 - half - 1, 8 + half + 1):
            c.put(x, y, bone[0] if x < 8 else bone[1])
    c.put(8, 13, bone[2])
    return _finish(c)


def dust(colors) -> Canvas:
    c = Canvas(16, 16)
    for x, y in ((5, 5), (9, 4), (11, 8), (7, 9), (4, 11), (10, 12), (8, 6), (6, 13), (12, 5)):
        c.put(x, y, colors[0])
        c.put(x + 1, y, colors[1])
        c.put(x, y + 1, colors[1])
    return _finish(c)


def wing() -> Canvas:
    c = Canvas(16, 16)
    skin = ramp("#b89ac8", "#7a5a8e", "#4a3460")
    for x in range(2, 14):
        top = 4 + abs(x - 8) // 2
        bottom = 11 - (1 if x % 3 == 0 else 0)
        for y in range(top, bottom):
            c.put(x, y, skin[0] if y < top + 2 else skin[1])
    for x in (4, 8, 12):
        c.vline(x, 5, 10, skin[2])
    return _finish(c)


def wisp_icon(colors) -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 9, 4, 4, colors[1])
    c.ellipse(7, 8, 2.2, 2.2, colors[0])
    for i in range(4):
        c.put(11 + i % 2, 4 + i, colors[1])
    return _finish(c)


def shell() -> Canvas:
    c = Canvas(16, 16)
    red = ramp("#ffc0a0", "#e0603a", "#a03a24")
    for y in range(4, 13):
        half = min(6, (y - 3) + 1)
        for x in range(8 - half, 8 + half):
            c.put(x, y, red[0] if y < 7 else red[1])
    for x in (5, 8, 11):
        c.vline(x, 6, 12, red[2])
    return _finish(c)


def bone_icon() -> Canvas:
    c = Canvas(16, 16)
    bone = ramp("#fffaf0", "#e0d4b8", "#a89878")
    for i in range(9):
        c.put(4 + i, 11 - i, bone[1])
        c.put(4 + i, 12 - i, bone[2])
    for cx, cy in ((3, 12), (4, 13), (12, 3), (13, 4)):
        c.ellipse(cx, cy, 1.4, 1.4, bone[0])
    return _finish(c)


def cog() -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 8, 5, 5, IRON[1])
    for x, y in ((8, 2), (8, 14), (2, 8), (14, 8), (4, 4), (12, 12), (4, 12), (12, 4)):
        c.rect(x - 1, y - 1, 2, 2, IRON[2])
    c.ellipse(8, 8, 2, 2, hex_color("#5fd6ff"))
    return _finish(c)


def whetstone() -> Canvas:
    c = Canvas(16, 16)
    stone = ramp("#c8d0d8", "#8a94a4", "#5a6274")
    for i in range(8):
        c.rect(3 + i, 10 - i, 3, 3, stone[1] if i % 2 else stone[0])
    c.hline(4, 11, 12, stone[2])
    return _finish(c)


def build_materials() -> dict[str, Canvas]:
    return {
        "slime_gel": blob(ramp("#d8ffc8", "#6ad05a", "#2f8a3a")),
        "toad_venom": potion(ramp("#e8ffa0", "#a0d040", "#5a8a20")),
        "venom_oil": potion(ramp("#f0ffd0", "#7ac05a", "#3a7a30")),
        "wolf_fang": fang(),
        "spirit_dust": dust(ramp("#f0fff8", "#9cfff0", "#3fd6d0")),
        "bat_wing": wing(),
        "wind_essence": wisp_icon(ramp("#f0fffc", "#9ce8e0", "#3aa8a0")),
        "shadow_essence": wisp_icon(ramp("#d8c8ff", "#6a4ac8", "#2a1e5a")),
        "crab_shell": shell(),
        "bone": bone_icon(),
        "gear_cog": cog(),
        "whetstone": whetstone(),
        "fang_charm": amulet(),
        "shell_mail": armor(ramp("#ffc0a0", "#e0603a", "#a03a24"), ramp("#fff0d8", "#e8d4b0", "#b89a70")),
        "bone_amulet": relic(),
        "cog_charm": cog(),
    }


def boot_icon() -> Canvas:
    c = Canvas(16, 16)
    c.rect(5, 3, 4, 8, LEATHER[2])
    c.rect(5, 10, 8, 3, LEATHER[1])
    c.hline(5, 12, 13, LEATHER[3] if len(LEATHER) > 3 else LEATHER[2])
    c.put(6, 4, LEATHER[0])
    return _finish(c)


def build_fish() -> dict[str, Canvas]:
    return {
        "perch": fish_icon(ramp("#f0ffd0", "#9ac850", "#4a7a2a"), 4.5, "#3a5a20"),
        "pike": fish_icon(ramp("#e0f0d0", "#7a9a6a", "#3a5a3a"), 5.5),
        "marsh_catfish": fish_icon(ramp("#e8d8c0", "#8a7058", "#4a3a2a"), 5.0),
        "glow_eel": fish_icon(ramp("#e8fffa", "#5ae8d0", "#1e7a70"), 6.0),
        "sea_bass": fish_icon(ramp("#e8f4ff", "#8ab4d8", "#3a5a88"), 4.8, "#5a7ab0"),
        "sun_tuna": fish_icon(ramp("#fff4c0", "#f0b040", "#a8641e"), 5.2),
        "golden_fish": fish_icon(ramp("#fffbe0", "#ffd45c", "#c88a2a"), 4.2),
        "old_boot": boot_icon(),
    }


def build_ash() -> dict[str, Canvas]:
    ember = ramp("#fff0b0", "#ffb040", "#e0601e", "#8a2a10")
    obsidian = ramp("#8a7a90", "#4a3e52", "#2a2230", "#16121a")
    hide = ramp("#8a7a70", "#5a4c46", "#3a302c")
    core = Canvas(16, 16)
    core.ellipse(8, 8, 5, 5, ember[3])
    core.ellipse(8, 8, 3.6, 3.6, ember[2])
    core.ellipse(7.5, 7.5, 2, 2, ember[1])
    core.put(7, 7, ember[0])
    shard = Canvas(16, 16)
    for y in range(2, 14):
        half = (y - 2) // 3 if y < 9 else (13 - y) // 2
        for x in range(8 - half, 9 + half):
            shard.put(x, y, obsidian[1] if x < 8 else obsidian[2])
    shard.put(7, 4, obsidian[0])
    pelt = Canvas(16, 16)
    pelt.rect(3, 4, 10, 8, hide[1])
    pelt.rect(4, 5, 8, 2, hide[0])
    for x in (3, 12):
        pelt.rect(x - 1, 3, 2, 2, hide[2])
        pelt.rect(x - 1, 11, 2, 2, hide[2])
    pelt.put(6, 9, ember[2])
    pelt.put(9, 8, ember[2])
    coal = Canvas(16, 16)
    coal.ellipse(8, 9, 5, 4, obsidian[2])
    coal.put(6, 8, ember[1])
    coal.put(9, 10, ember[2])
    coal.put(10, 7, ember[0])
    return {
        "ember_core": _finish(core), "obsidian_shard": _finish(shard), "ash_hide": _finish(pelt),
        "ember_coal": _finish(coal),
        "ember_fish": fish_icon(ramp("#fff0b0", "#ff8a2a", "#a8341a"), 4.6),
        "magma_eel": fish_icon(ramp("#ffd070", "#c4461a", "#5a1206"), 6.0),
        "obsidian_blade": sword(ramp("#b8a8c8", "#5a4a68", "#2a2232"), GOLD, "#ff8a2a"),
        "ash_cloak": armor(ramp("#9a8a80", "#5a4c46", "#3a302c"), ramp("#ffc060", "#e0601e", "#8a2a10")),
        "flame_heart": relic(),
        "recipe_obsidian": scroll_icon(),
        "star_fragment": _star_icon(),
        "treasure_map": _map_icon(),
        "jelly_staff": staff(ramp("#e0ffd0", "#7ad05a", "#2f8a3a")),
        "dusk_fang": fang(),
        "toad_crown": gem(ramp("#f0ffc0", "#a0d040", "#5a8a20")),
        "crab_aegis": armor(ramp("#e0e8f4", "#9aa8c0", "#5c6a84"), ramp("#fff0d8", "#e8d4b0", "#b89a70")),
        "golem_heart": gem(ramp("#fff0c0", "#e0a040", "#8a5a20")),
        "spark_collar": gem(ramp("#fff0b0", "#ff8a2a", "#a8341a")),
        "pattern_shard": _pattern_shard(),
        "sky_thread": gem(ramp("#f0ffff", "#7adcff", "#3a70c0")),
        "earth_star": gem(ramp("#fffbe0", "#ffd060", "#a86a20")),
    }


def _pattern_shard() -> Canvas:
    c = Canvas(16, 16)
    light = ramp("#fff6e0", "#c8a0ff", "#6a3aa8")
    for y in range(2, 14):
        half = (y - 2) // 3 if y < 9 else (13 - y) // 2
        for x in range(8 - half, 9 + half):
            c.put(x, y, light[1] if x < 8 else light[2])
    c.put(7, 4, light[0])
    c.put(8, 6, light[0])
    c.put(7, 8, light[0])
    return _finish(c)


def _map_icon() -> Canvas:
    c = Canvas(16, 16)
    paper = ramp("#fff2d0", "#e8d4a4", "#c4a670")
    c.rect(2, 3, 12, 10, paper[1])
    c.rect(3, 4, 10, 8, paper[0])
    for x in (2, 13):
        c.vline(x, 3, 12, paper[2])
    c.put(5, 6, hex_color("#7a9a5a"))
    c.put(6, 7, hex_color("#7a9a5a"))
    c.put(8, 8, hex_color("#5a8ac0"))
    red = hex_color("#d0302a")
    for i in range(3):
        c.put(9 + i, 6 + i, red)
        c.put(11 - i, 6 + i, red)
    return _finish(c)


def _star_icon() -> Canvas:
    c = Canvas(16, 16)
    gold = ramp("#fffbe0", "#ffe07a", "#e0a030")
    for i in range(-5, 6):
        c.put(8 + i, 8, gold[1] if abs(i) < 3 else gold[2])
        c.put(8, 8 + i, gold[1] if abs(i) < 3 else gold[2])
    for i in range(-2, 3):
        c.put(8 + i, 8 + i, gold[1])
        c.put(8 + i, 8 - i, gold[1])
    c.put(8, 8, gold[0])
    c.put(7, 7, gold[0])
    return _finish(c)
