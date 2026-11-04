"""Village buildings and props drawn to match the purchased pack's style:
warm orange shingle roofs, cream plaster with dark timber, stone footings and
dark-brown outlines (palette sampled from the pack's forge, stalls and wagon).

Called from tools/art/chibi.py; writes assets/world/village_*.png and their
bottom-centre origins into assets/art_manifest.json.
"""
from __future__ import annotations

import json
import pathlib
import random

from pixel import Canvas, hex_color

OUTLINE = hex_color("#302423")
ROOF = [hex_color(c) for c in ("#7a3a16", "#9b4916", "#b15820", "#ce6123", "#db7434", "#e89a5c")]
SLATE = [hex_color(c) for c in ("#2a2c44", "#34354e", "#4d6285", "#5f7aa0", "#7a96bc", "#a4bcd8")]
PLASTER = [hex_color(c) for c in ("#a8946a", "#cdb98f", "#e9dcb9", "#f6f5d8")]
TIMBER = [hex_color(c) for c in ("#442d31", "#66442d", "#744d33", "#a27047", "#b9875a")]
STONE = [hex_color(c) for c in ("#3e3a34", "#544e45", "#6e6659", "#7b7765", "#97927c", "#b8b49c")]
GLASS = [hex_color(c) for c in ("#0c1a37", "#34354e", "#4d6285", "#9ab4d8")]
GREEN = [hex_color(c) for c in ("#24432c", "#335c38", "#4a7a42", "#6c9a50", "#9cc062")]
SOIL = [hex_color(c) for c in ("#3a2a22", "#4c342a", "#66442d", "#8c6344")]
HAY = [hex_color(c) for c in ("#8a6a2a", "#b8923a", "#dcbc5a", "#f2dc8a")]
GOLD = hex_color("#f4b41b")


def _roof(c: Canvas, x0: int, y0: int, w: int, h: int, pal, seed: int) -> None:
    rng = random.Random(seed)
    for row, y in enumerate(range(y0, y0 + h, 5)):
        offset = (row % 2) * 3
        for x in range(x0, x0 + w):
            for dy in range(5):
                if y + dy >= y0 + h:
                    continue
                tile = (x - x0 + offset) % 6
                shade = 3
                if dy == 4:
                    shade = 1
                elif dy == 0:
                    shade = 4
                elif tile == 0:
                    shade = 2
                if rng.random() < 0.05:
                    shade = max(1, shade - 1)
                c.put(x, y + dy, pal[shade])
    c.hline(x0, x0 + w - 1, y0, pal[5])
    c.hline(x0, x0 + w - 1, y0 + h - 1, pal[0])
    c.hline(x0 + 1, x0 + w - 2, y0 + h, pal[0])


def _window(c: Canvas, x: int, y: int, w: int = 8, h: int = 8, flowers: bool = False) -> None:
    c.rect(x - 1, y - 1, w + 2, h + 2, TIMBER[3])
    c.rect(x, y, w, h, GLASS[1])
    c.rect(x, y, w, 2, GLASS[2])
    c.put(x + 1, y + 1, GLASS[3])
    c.vline(x + w // 2, y, y + h - 1, TIMBER[2])
    c.hline(x, x + w - 1, y + h // 2, TIMBER[2])
    if flowers:
        c.rect(x - 1, y + h + 1, w + 2, 3, TIMBER[1])
        for k in range(0, w + 2, 2):
            c.put(x - 1 + k, y + h, (hex_color("#e05a6a") if k % 4 == 0 else hex_color("#f6d65a")))
            c.put(x + k, y + h, GREEN[3])


def _door(c: Canvas, x: int, y: int, w: int = 10, h: int = 14) -> None:
    c.rect(x - 1, y - 1, w + 2, h + 1, TIMBER[0])
    c.rect(x, y, w, h, TIMBER[1])
    for k in range(x + 2, x + w, 3):
        c.vline(k, y, y + h - 1, TIMBER[2])
    c.put(x + w - 3, y + h // 2, GOLD)


def house(width: int = 72, roof_pal=ROOF, windows: int = 1, chimney: bool = True, seed: int = 1,
          sign: bool = False) -> tuple[Canvas, tuple[int, int]]:
    """Cottage seen from the front-top: roof above, timbered wall below."""
    roof_h = int(width * 0.55)
    wall_h = 28
    h = roof_h + wall_h + 6
    c = Canvas(width + 4, h + 4)
    left, top = 2, 2
    wall_x0, wall_x1 = left + 4, left + width - 5
    wall_y0 = top + roof_h - 2
    # Shadow on the ground.
    for x in range(left, left + width):
        c.blend(x, top + h, (20, 14, 10, 70))
        c.blend(x, top + h + 1, (20, 14, 10, 40))
    # Stone footing.
    c.rect(wall_x0 - 1, wall_y0 + wall_h - 3, wall_x1 - wall_x0 + 3, 6, STONE[2])
    for x in range(wall_x0 - 1, wall_x1 + 2, 5):
        c.vline(x, wall_y0 + wall_h - 3, wall_y0 + wall_h + 2, STONE[1])
    c.hline(wall_x0 - 1, wall_x1 + 1, wall_y0 + wall_h - 3, STONE[4])
    # Plaster wall with timber frame.
    c.rect(wall_x0, wall_y0, wall_x1 - wall_x0 + 1, wall_h - 3, PLASTER[2])
    c.rect(wall_x0, wall_y0, 2, wall_h - 3, TIMBER[2])
    c.rect(wall_x1 - 1, wall_y0, 2, wall_h - 3, TIMBER[2])
    c.hline(wall_x0, wall_x1, wall_y0 + 1, TIMBER[1])
    c.hline(wall_x0, wall_x1, wall_y0 + 2, TIMBER[2])
    for y in range(wall_y0 + 3, wall_y0 + wall_h - 3):
        c.put(wall_x0 + 2, y, PLASTER[1])
    # Door and windows.
    mid = (wall_x0 + wall_x1) // 2
    _door(c, mid - 5, wall_y0 + wall_h - 17)
    spots = [wall_x0 + 7, wall_x1 - 15] if windows >= 2 else [wall_x0 + 7 if width < 80 else wall_x1 - 15]
    for k, x in enumerate(spots):
        _window(c, x, wall_y0 + 7, flowers=(k == 0))
    if sign:
        c.rect(wall_x1 - 14, wall_y0 + 5, 12, 7, TIMBER[3])
        c.rect(wall_x1 - 13, wall_y0 + 6, 10, 5, TIMBER[4])
    # Roof with overhang.
    _roof(c, left, top + 6, width, roof_h - 6, roof_pal, seed)
    # Gable ridge and chimney.
    c.hline(left + 3, left + width - 4, top + 5, roof_pal[4])
    c.hline(left + 6, left + width - 7, top + 4, roof_pal[5])
    if chimney:
        cx = left + width - 18
        c.rect(cx, top - 1, 8, 12, STONE[2])
        c.rect(cx, top - 1, 8, 2, STONE[4])
        c.vline(cx, top - 1, top + 10, STONE[1])
    c.outline(OUTLINE)
    return c, (c.w // 2, top + h - 1)


def fence(horizontal: bool = True) -> tuple[Canvas, tuple[int, int]]:
    if horizontal:
        c = Canvas(34, 16)
        for x in (2, 16, 30):
            c.rect(x, 2, 3, 12, TIMBER[2])
            c.put(x, 2, TIMBER[4])
        for y in (5, 10):
            c.rect(1, y, 33, 2, TIMBER[3])
            c.hline(1, 33, y, TIMBER[4])
        c.outline(OUTLINE)
        return c, (17, 14)
    c = Canvas(8, 36)
    c.rect(2, 2, 3, 32, TIMBER[3])
    for y in (3, 17, 31):
        c.rect(1, y, 5, 3, TIMBER[2])
    c.outline(OUTLINE)
    return c, (4, 34)


def well() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(34, 40)
    # Roof and posts.
    c.rect(5, 6, 2, 22, TIMBER[1])
    c.rect(27, 6, 2, 22, TIMBER[1])
    _roof(c, 2, 2, 30, 8, ROOF, 7)
    c.hline(16, 18, 14, TIMBER[0])
    c.vline(17, 11, 20, hex_color("#9d9c97"))
    # Stone ring.
    for y in range(22, 36):
        for x in range(4, 30):
            d = ((x - 16.5) / 13) ** 2 + ((y - 28) / 7) ** 2
            if d <= 1:
                c.put(x, y, STONE[3] if (x // 4 + y // 3) % 2 else STONE[2])
    for y in range(24, 30):
        for x in range(8, 26):
            if ((x - 16.5) / 9) ** 2 + ((y - 26.5) / 3) ** 2 <= 1:
                c.put(x, y, GLASS[0] if y > 25 else GLASS[1])
    c.outline(OUTLINE)
    return c, (17, 36)


def field() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(66, 42)
    c.rect(1, 1, 64, 40, SOIL[1])
    rng = random.Random(3)
    for row, y in enumerate(range(4, 40, 6)):
        c.hline(2, 63, y, SOIL[3])
        c.hline(2, 63, y + 1, SOIL[2])
        for x in range(5, 62, 6):
            if rng.random() < 0.85:
                c.put(x, y - 1, GREEN[3])
                c.put(x - 1, y - 2, GREEN[4])
                c.put(x + 1, y - 2, GREEN[2])
    c.outline(OUTLINE)
    return c, (33, 41)


def signpost() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(20, 26)
    c.rect(9, 6, 3, 19, TIMBER[2])
    c.rect(2, 4, 16, 6, TIMBER[3])
    c.hline(2, 17, 4, TIMBER[4])
    c.rect(4, 11, 13, 5, TIMBER[3])
    c.hline(5, 14, 6, TIMBER[1])
    c.hline(6, 15, 13, TIMBER[1])
    c.outline(OUTLINE)
    return c, (10, 24)


def haybale() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(22, 18)
    c.rect(2, 3, 18, 13, HAY[2])
    c.rect(2, 3, 18, 3, HAY[3])
    c.rect(2, 13, 18, 3, HAY[1])
    c.vline(7, 3, 15, HAY[0])
    c.vline(15, 3, 15, HAY[0])
    c.outline(OUTLINE)
    return c, (11, 16)


def lamp() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(12, 34)
    c.rect(5, 8, 2, 24, TIMBER[1])
    c.rect(3, 31, 6, 2, STONE[2])
    c.rect(2, 2, 8, 7, TIMBER[0])
    c.rect(3, 3, 6, 5, hex_color("#ffd87a"))
    c.put(4, 4, hex_color("#fff6c8"))
    c.outline(OUTLINE)
    return c, (6, 32)


def board() -> tuple[Canvas, tuple[int, int]]:
    """Settlement notice board with pinned plans."""
    c = Canvas(34, 34)
    c.rect(4, 10, 3, 22, TIMBER[1])
    c.rect(27, 10, 3, 22, TIMBER[1])
    c.rect(2, 4, 30, 18, TIMBER[3])
    c.rect(3, 5, 28, 16, TIMBER[2])
    _roof(c, 1, 1, 32, 4, ROOF, 9)
    for x, y, col in ((5, 7, PLASTER[3]), (14, 8, PLASTER[2]), (22, 6, PLASTER[3])):
        c.rect(x, y, 7, 9, col)
        c.hline(x + 1, x + 5, y + 3, TIMBER[1])
        c.hline(x + 1, x + 4, y + 5, TIMBER[1])
        c.put(x + 3, y, hex_color("#e05a6a"))
    c.outline(OUTLINE)
    return c, (17, 32)


def plot() -> tuple[Canvas, tuple[int, int]]:
    """Empty building plot: stakes and string around flattened earth."""
    c = Canvas(70, 44)
    for y in range(4, 40):
        for x in range(4, 66):
            if (x + y) % 9 == 0:
                c.put(x, y, SOIL[3])
    for x, y in ((3, 3), (65, 3), (3, 39), (65, 39)):
        c.rect(x - 1, y - 4, 2, 6, TIMBER[3])
    for x in range(4, 65, 2):
        c.put(x, 3, PLASTER[3])
        c.put(x, 39, PLASTER[3])
    for y in range(4, 39, 2):
        c.put(3, y, PLASTER[3])
        c.put(65, y, PLASTER[3])
    return c, (35, 41)


def build(root: pathlib.Path) -> None:
    items = {
        "village_house_small": house(64, seed=1),
        "village_house_large": house(92, windows=2, seed=2),
        "village_house_slate": house(72, roof_pal=SLATE, seed=3, sign=True),
        "village_hall": house(110, windows=2, seed=4, chimney=False, sign=True),
        "village_fence_h": fence(True),
        "village_fence_v": fence(False),
        "village_well": well(),
        "village_field": field(),
        "village_sign": signpost(),
        "village_hay": haybale(),
        "village_lamp": lamp(),
        "village_plot": plot(),
        "village_board": board(),
    }
    manifest_path = root / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    for name, (canvas, origin) in items.items():
        rel = f"world/{name}.png"
        canvas.save(root / "assets" / rel)
        art[rel] = {"size": [canvas.w, canvas.h], "origin": list(origin)}
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("  village: " + ", ".join(items))


# --- Interface frames in the pack's warm wood palette ------------------------

UI_BG = hex_color("#211715")
UI_BG2 = hex_color("#2e211d")


def ui_panel(gold: bool = False) -> Canvas:
    """24x24 nine-slice: dark wood inside, timber border, brass corner studs."""
    c = Canvas(24, 24)
    c.rect(0, 0, 24, 24, OUTLINE)
    c.rect(1, 1, 22, 22, TIMBER[2])
    c.rect(1, 1, 22, 1, TIMBER[4])
    c.rect(1, 22, 22, 1, TIMBER[0])
    c.rect(2, 2, 20, 20, TIMBER[1])
    c.rect(3, 3, 18, 18, OUTLINE)
    c.rect(4, 4, 16, 16, UI_BG)
    c.rect(4, 4, 16, 1, UI_BG2)
    stud = [hex_color("#f2dc8a"), GOLD, hex_color("#b8862a")] if gold else [TIMBER[4], TIMBER[3], TIMBER[1]]
    for x, y in ((1, 1), (21, 1), (1, 21), (21, 21)):
        c.put(x, y, stud[1])
        c.put(x + 1, y, stud[2])
        c.put(x, y + 1, stud[2])
        c.put(x + 1, y + 1, stud[0] if gold else stud[1])
    return c


def ui_button(state: str) -> Canvas:
    """12x12 nine-slice button: plank face; hover brighter, pressed sunk."""
    face = {"normal": TIMBER[2], "hover": TIMBER[3], "pressed": TIMBER[1], "disabled": hex_color("#4a3a34")}[state]
    light = {"normal": TIMBER[3], "hover": TIMBER[4], "pressed": TIMBER[2], "disabled": hex_color("#5a4a42")}[state]
    c = Canvas(12, 12)
    c.rect(0, 0, 12, 12, OUTLINE)
    c.rect(1, 1, 10, 10, face)
    if state == "pressed":
        c.hline(1, 10, 1, TIMBER[0])
    else:
        c.hline(1, 10, 1, light)
        c.hline(1, 10, 10, TIMBER[0])
    if state == "hover":
        for x, y in ((1, 1), (10, 1), (1, 10), (10, 10)):
            c.put(x, y, GOLD)
    return c


def build_ui(root: pathlib.Path) -> None:
    folder = root / "assets" / "ui"
    folder.mkdir(parents=True, exist_ok=True)
    ui_panel(False).save(folder / "panel.png")
    ui_panel(True).save(folder / "panel_gold.png")
    for state in ("normal", "hover", "pressed", "disabled"):
        ui_button(state).save(folder / f"button_{state}.png")
    print("  ui: panel, panel_gold, buttons")


# --- Gathering points and the kitchen ---------------------------------------

def gather_wood() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(30, 18)
    for y in range(14, 18):
        for x in range(2, 28):
            c.blend(x, y, (20, 14, 10, 50))
    for k, (x, y) in enumerate(((4, 9), (12, 9), (8, 4))):
        c.rect(x, y, 14, 6, TIMBER[2] if k != 2 else TIMBER[3])
        c.hline(x, x + 13, y, TIMBER[4])
        c.rect(x + 12, y, 3, 6, TIMBER[4])
        c.put(x + 13, y + 2, TIMBER[1])
        c.put(x + 13, y + 3, TIMBER[2])
    c.outline(OUTLINE)
    return c, (15, 15)


def gather_stone() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(26, 20)
    for y in range(4, 18):
        for x in range(2, 24):
            d = ((x - 12.5) / 11) ** 2 + ((y - 12) / 7.5) ** 2
            if d <= 1:
                c.put(x, y, STONE[4] if y < 9 and x < 14 else (STONE[3] if d < 0.6 else STONE[2]))
    for x, y in ((8, 10), (15, 8), (12, 14)):
        c.put(x, y, STONE[1])
        c.put(x + 1, y, STONE[1])
    c.outline(OUTLINE)
    return c, (13, 17)


def gather_fish() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(24, 12)
    ripple = (220, 240, 255, 200)
    for x in range(3, 21):
        y = 6 + (1 if (x // 3) % 2 else 0)
        c.blend(x, y, ripple)
    for x in range(7, 17):
        c.blend(x, 3, ripple)
    for x in range(9, 15):
        c.put(x, 8, hex_color("#2a3a5a"))
    c.put(15, 7, hex_color("#2a3a5a"))
    c.put(16, 9, hex_color("#2a3a5a"))
    return c, (12, 10)


def _plant(flower, leaves=GREEN) -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(16, 16)
    for x, y in ((7, 12), (6, 11), (9, 11), (5, 13), (10, 13), (8, 10)):
        c.put(x, y, leaves[3])
    for x, y in ((4, 12), (11, 12), (7, 9)):
        c.put(x, y, leaves[2])
    c.vline(8, 6, 13, leaves[2])
    for x, y in ((7, 5), (9, 5), (8, 4), (8, 6), (5, 8), (11, 8)):
        c.put(x, y, flower[1])
    c.put(8, 5, flower[0])
    c.outline(OUTLINE)
    return c, (8, 14)


def kitchen() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(30, 30)
    for x, y in ((6, 24), (24, 24)):
        c.rect(x - 1, 6, 2, y - 4, TIMBER[1])
    c.hline(4, 26, 6, TIMBER[2])
    c.vline(15, 6, 12, hex_color("#5a5a5a"))
    for y in range(12, 23):
        for x in range(7, 24):
            if ((x - 15.5) / 8) ** 2 + ((y - 16) / 6) ** 2 <= 1:
                c.put(x, y, hex_color("#3a3a40") if y > 13 else hex_color("#6a6a72"))
    c.hline(9, 22, 12, hex_color("#c8a060"))
    for x in range(10, 22, 3):
        c.put(x, 11, hex_color("#e8d8a8"))
    for x, col in ((10, "#ffb040"), (13, "#ff7a2a"), (16, "#ffd060"), (19, "#ff7a2a")):
        c.put(x, 24, hex_color(col))
        c.put(x, 23, hex_color("#ffd060"))
    c.rect(6, 25, 19, 3, STONE[2])
    c.outline(OUTLINE)
    return c, (15, 27)


def build_gathering(root: pathlib.Path) -> None:
    items = {
        "gather_wood": gather_wood(), "gather_stone": gather_stone(), "gather_fish": gather_fish(),
        "gather_healroot": _plant([hex_color("#ffd0c0"), hex_color("#e05a4a")]),
        "gather_bluebell": _plant([hex_color("#e0f0ff"), hex_color("#5a8ae0")]),
        "station_kitchen": kitchen(),
    }
    manifest_path = root / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    for name, (canvas, origin) in items.items():
        rel = f"world/{name}.png"
        canvas.save(root / "assets" / rel)
        art[rel] = {"size": [canvas.w, canvas.h], "origin": list(origin)}
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("  gathering: " + ", ".join(items))



# --- Salt Coast ------------------------------------------------------------------

def lighthouse(lit: bool) -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(44, 112)
    white, red = PLASTER, [hex_color(x) for x in ("#7a1e1e", "#a8302a", "#d04a3a", "#e8705a")]
    base_y = 108
    for y in range(102, 111):
        for x in range(2, 42):
            if ((x - 22) / 20) ** 2 + ((y - 106) / 4.5) ** 2 <= 1:
                c.put(x, y, STONE[2] if y > 104 else STONE[3])
    for y in range(30, 104):
        t = (y - 30) / 74
        half = 8 + t * 7
        band = ((y - 30) // 12) % 2 == 1
        for x in range(int(22 - half), int(22 + half) + 1):
            side = (x - (22 - half)) / (2 * half)
            pal = red if band else white
            c.put(x, y, pal[3] if side < 0.25 else (pal[2] if side < 0.7 else pal[1]))
    c.rect(16, 86, 12, 18, TIMBER[1])
    c.rect(17, 87, 10, 16, TIMBER[2])
    _window(c, 19, 60, 6, 7)
    c.rect(11, 26, 22, 4, STONE[1])
    c.rect(13, 12, 18, 14, GLASS[1] if not lit else hex_color("#ffe08a"))
    if lit:
        c.rect(15, 14, 14, 10, hex_color("#fff6c8"))
    for x in (13, 21, 30):
        c.vline(x, 12, 25, STONE[1])
    _roof(c, 11, 4, 22, 8, red + [red[3], red[3]], 21)
    c.outline(OUTLINE)
    return c, (22, base_y)


def pier() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(110, 26)
    for x in range(2, 108):
        for y in range(6, 18):
            c.put(x, y, TIMBER[3] if (x // 7) % 2 else TIMBER[2])
        if x % 7 == 0:
            c.vline(x, 6, 17, TIMBER[1])
    c.hline(2, 107, 6, TIMBER[4])
    for x in range(6, 106, 20):
        c.rect(x, 17, 3, 7, TIMBER[1])
    c.outline(OUTLINE)
    return c, (55, 18)


def boat() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(40, 18)
    for y in range(6, 16):
        half = 18 - (y - 6) * 0.9
        for x in range(int(20 - half), int(20 + half)):
            c.put(x, y, TIMBER[3] if y < 9 else TIMBER[2])
    c.hline(4, 35, 6, TIMBER[4])
    c.rect(18, 2, 2, 6, TIMBER[1])
    c.outline(OUTLINE)
    return c, (20, 15)


def nets() -> tuple[Canvas, tuple[int, int]]:
    c = Canvas(30, 26)
    c.rect(2, 4, 2, 20, TIMBER[1])
    c.rect(26, 4, 2, 20, TIMBER[1])
    c.hline(2, 27, 4, TIMBER[3])
    for y in range(6, 20, 3):
        for x in range(4, 26, 3):
            c.put(x, y, PLASTER[1])
            c.put(x + 1, y + 1, PLASTER[0])
    c.outline(OUTLINE)
    return c, (15, 24)


def build_coast(root: pathlib.Path) -> None:
    items = {"coast_lighthouse": lighthouse(False), "coast_lighthouse_lit": lighthouse(True),
             "coast_pier": pier(), "coast_boat": boat(), "coast_nets": nets()}
    manifest_path = root / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    for name, (canvas, origin) in items.items():
        rel = f"world/{name}.png"
        canvas.save(root / "assets" / rel)
        art[rel] = {"size": [canvas.w, canvas.h], "origin": list(origin)}
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("  coast: " + ", ".join(items))
