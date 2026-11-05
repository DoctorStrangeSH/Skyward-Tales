#!/usr/bin/env python3
"""Builds the chibi character sheets from the purchased sprite pack.

Usage: python3 tools/art/chibi.py

Source: assets/incoming/ (Legacy Red, Companion, Blacksmith, Herbalist,
Potion Maker). Pack sheets have 5 direction rows (down, down-right, right,
up-right, up) of 64x64 cells; the game wants 8 rows in DirectionalSprite
order (down, down-right, right, up-right, up, up-left, left, down-left), so
the left-facing rows are mirrored.

Every other character is drawn "like them": recoloured from Legacy Red or the
Companion, with hair trimmed short for men, beards and ghostly tints, so the
whole cast shares one style. Output:
  assets/sprites/chibi/<id>/<anim>.png   8 rows x N frames
  assets/sprites/chibi/manifest.json     cell size, frames per anim, feet y
  assets/sprites/portraits/<id>.png      head crop for dialogue
"""
from __future__ import annotations

import json
import pathlib

import numpy as np
from PIL import Image

import sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "incoming"
OUT = ROOT / "assets" / "sprites" / "chibi"
PORTRAITS = ROOT / "assets" / "sprites" / "portraits"
CELL = 64

# Legacy Red palette (exact pack colours).
HAIR_LIGHT = (255, 255, 242)
HAIR_SHADE = (191, 195, 198)
RED_DARK = (124, 25, 26)
RED_MID = (170, 39, 44)
RED_LIGHT = (209, 64, 31)
SKIN_LIGHT = (254, 225, 184)
SKIN_SHADE = (235, 150, 97)
GOLD = (244, 180, 27)
INK = (17, 17, 17)
MAUVE = (91, 61, 63)


def load(rel: str) -> np.ndarray:
    return np.array(Image.open(SRC / rel).convert("RGBA"))


def over(base: np.ndarray, layer: np.ndarray) -> np.ndarray:
    """Alpha-composites an effect sheet (slash swoosh) over the body sheet."""
    a = Image.fromarray(base)
    a.alpha_composite(Image.fromarray(layer))
    return np.array(a)


def to_eight(sheet: np.ndarray, cell: int = CELL) -> np.ndarray:
    """5 pack rows -> 8 game rows (left-facing rows mirrored)."""
    rows = [sheet[r * cell:(r + 1) * cell] for r in range(5)]
    frames = sheet.shape[1] // cell

    def mirror(row: np.ndarray) -> np.ndarray:
        out = row.copy()
        for f in range(frames):
            out[:, f * cell:(f + 1) * cell] = row[:, f * cell:(f + 1) * cell][:, ::-1]
        return out

    order = [rows[0], rows[1], rows[2], rows[3], rows[4], mirror(rows[3]), mirror(rows[2]), mirror(rows[1])]
    return np.concatenate(order, axis=0)


def cells(sheet: np.ndarray, cell_w: int, cell_h: int):
    for y in range(0, sheet.shape[0], cell_h):
        for x in range(0, sheet.shape[1], cell_w):
            yield sheet[y:y + cell_h, x:x + cell_w]


def mask(a: np.ndarray, *colors) -> np.ndarray:
    m = np.zeros(a.shape[:2], dtype=bool)
    for c in colors:
        m |= np.all(a[:, :, :3] == c, axis=2)
    return m & (a[:, :, 3] > 0)


def recolor(a: np.ndarray, mapping: dict) -> None:
    for src, dst in mapping.items():
        m = mask(a, src)
        a[m, :3] = dst


def trim_hair(cell: np.ndarray, keep: int = 9, hair=(HAIR_LIGHT, HAIR_SHADE), fill=(RED_DARK, RED_MID)) -> None:
    """Cut long hair to chin length; over the back, cloak shows instead."""
    hair_m = mask(cell, *hair)
    rows = np.where(hair_m.sum(1) >= 4)[0]
    if len(rows) == 0:
        return
    cut = rows[0] + keep
    body = (cell[:, :, 3] > 200) & ~hair_m
    for y in range(cut, cell.shape[0]):
        for x in np.where(hair_m[y])[0]:
            if body[y + 1:y + 8, x].any():
                light = tuple(cell[y, x, :3]) == hair[0]
                cell[y, x] = (*(fill[1] if light else fill[0]), 255)
            else:
                cell[y, x] = (0, 0, 0, 0)


def add_beard(cell: np.ndarray, color, shade) -> None:
    """Beard over the lower face and chest (front and three-quarter rows)."""
    skin = mask(cell, SKIN_LIGHT, SKIN_SHADE)
    ys, xs = np.nonzero(skin)
    if len(ys) < 4:
        return
    bottom = ys.max()
    for y in range(bottom - 1, bottom + 4):
        span = xs[ys >= bottom - 2] if y > bottom else xs[ys == y]
        if len(span) == 0:
            continue
        x0, x1 = span.min(), span.max()
        if y > bottom:
            x0, x1 = x0 + (y - bottom) // 2, x1 - (y - bottom) // 2
        for x in range(x0, x1 + 1):
            if cell[y, x, 3] > 0 or y > bottom:
                cell[y, x] = (*(shade if (x + y) % 3 == 0 else color), 255)


def remove_ahoge(cell: np.ndarray, hair=(HAIR_LIGHT, HAIR_SHADE)) -> None:
    hair_m = mask(cell, *hair)
    rows = np.where(hair_m.sum(1) >= 4)[0]
    if len(rows):
        cell[: rows[0]] = 0


def make_variant(sheet: np.ndarray, *, colors: dict, trim: bool = False, beard=None, ahoge: bool = True,
                 alpha: float = 1.0, fill=(RED_DARK, RED_MID), front_rows=(0, 1, 2, 6, 7)) -> np.ndarray:
    out = sheet.copy()
    frames = out.shape[1] // CELL
    for r in range(8):
        for f in range(frames):
            c = out[r * CELL:(r + 1) * CELL, f * CELL:(f + 1) * CELL]
            if not ahoge:
                remove_ahoge(c)
            if trim:
                trim_hair(c, fill=fill)
            if beard is not None and r in front_rows:
                add_beard(c, *beard)
    recolor(out, colors)
    if alpha < 1.0:
        out[:, :, 3] = (out[:, :, 3] * alpha).astype(np.uint8)
    return out


def single_row(rel: str, frames: int, cell_w: int) -> np.ndarray:
    """Idle-only NPCs face the camera: one row repeated for all 8 directions."""
    row = load(rel)[:, : frames * cell_w]
    return np.concatenate([row] * 8, axis=0)


def feet_y(sheet: np.ndarray, cell_h: int) -> int:
    first = sheet[:cell_h, : sheet.shape[1]]
    ys = np.nonzero(first[:, :, 3] > 150)[0]
    return int(ys.max()) if len(ys) else cell_h


def portrait(sheet: np.ndarray, cell_w: int, cell_h: int) -> Image.Image:
    c = sheet[:cell_h, :cell_w]
    solid = c[:, :, 3] > 150
    ys, xs = np.nonzero(solid)
    top = ys.min()
    head_xs = xs[ys < top + 8]
    cx = int(round(head_xs.mean()))
    size = 18
    x0 = max(0, cx - size // 2)
    y0 = max(0, top - 2)
    crop = np.zeros((size, size, 4), dtype=np.uint8)
    part = c[y0:y0 + size, x0:x0 + size]
    crop[: part.shape[0], : part.shape[1]] = part
    return Image.fromarray(crop)


def save(char_id: str, anims: dict, cell_w: int = CELL, cell_h: int = CELL, manifest: dict | None = None) -> None:
    folder = OUT / char_id
    folder.mkdir(parents=True, exist_ok=True)
    entry = {"cell": [cell_w, cell_h], "anims": {}}
    for name, sheet in anims.items():
        Image.fromarray(sheet).save(folder / f"{name}.png")
        entry["anims"][name] = sheet.shape[1] // cell_w
    first = anims.get("idle", next(iter(anims.values())))
    entry["feet"] = feet_y(first, cell_h)
    PORTRAITS.mkdir(parents=True, exist_ok=True)
    portrait(first, cell_w, cell_h).save(PORTRAITS / f"{char_id}.png")
    manifest[char_id] = entry
    print(f"  chibi/{char_id}: " + ", ".join(f"{k}×{v}" for k, v in entry["anims"].items()))


def concat(*sheets: np.ndarray) -> np.ndarray:
    return np.concatenate(sheets, axis=1)


# Village decorations cut from Decorations.png: name -> (x, y, w, h).
DECOR = {
    "forge": (6, 0, 54, 62), "wagon": (8, 68, 50, 53),
    "stall_orange": (62, 7, 64, 59), "stall_blue": (126, 7, 64, 59), "stall_white": (190, 7, 66, 59),
    "armor_stand": (15, 138, 18, 37), "weapon_rack": (35, 150, 23, 25), "workbench": (62, 154, 34, 22),
    "potion_table": (114, 152, 29, 40), "bookcase": (33, 174, 29, 34), "potted_plant": (65, 186, 14, 22),
}


def build_decor() -> None:
    """Saves each decoration as assets/world/decor_<name>.png with its
    bottom-centre origin in assets/art_manifest.json (WorldArt convention)."""
    sheet = Image.open(SRC / "Decorations" / "Decorations.png").convert("RGBA")
    manifest_path = ROOT / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    for name, (x, y, w, h) in DECOR.items():
        crop = sheet.crop((x, y, x + w, y + h))
        box = crop.getbbox()
        crop = crop.crop(box)
        rel = f"world/decor_{name}.png"
        crop.save(ROOT / "assets" / rel)
        art[rel] = {"size": [crop.width, crop.height], "origin": [crop.width // 2, crop.height - 2]}
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("  decor: " + ", ".join(DECOR))


def main() -> int:
    manifest: dict = {}
    red = "Hero/Legacy Red/"
    hero = {
        "walk": to_eight(load(red + "Walk.png")),
        "idle": to_eight(load(red + "Idle Default.png")),
        "cast": to_eight(concat(load(red + "Default Charge Start.png"), load(red + "Default Charge End.png"))),
        "roll": to_eight(load(red + "Roll.png")),
        "hit": to_eight(load(red + "Hit.png")),
        "faint": to_eight(load(red + "Faint.png")),
        # Sword: two slashes with their swoosh, a held charge and the spin.
        "slash1": to_eight(over(load(red + "Slash 1 Default.png"), load(red + "Slash 1 Default Vfx.png"))),
        "slash2": to_eight(over(load(red + "Slash 2 Default.png"), load(red + "Slash 2 Default Vfx.png"))),
        "charge": to_eight(load(red + "Sword Charge Loop.png")),
        "spin": to_eight(load(red + "Sword Spin White.png")),
    }
    save("hero_f", hero, manifest=manifest)

    # Male hero drawn in the same style: short dark hair, blue coat.
    male_colors = {HAIR_LIGHT: (128, 84, 60), HAIR_SHADE: (86, 54, 44), RED_DARK: (34, 58, 104),
                   RED_MID: (52, 92, 156), RED_LIGHT: (88, 150, 210), MAUVE: (40, 44, 70)}
    save("hero_m", {k: make_variant(v, colors=male_colors, trim=True, fill=(RED_DARK, RED_MID)) for k, v in hero.items()}, manifest=manifest)

    comp = "Companion/"
    mira = {
        "walk": to_eight(load(comp + "Walk.png")),
        "idle": to_eight(load(comp + "Idle Default.png")),
        "throw": to_eight(load(comp + "Throw.png")),
        "hit": to_eight(load(comp + "Hit.png")),
    }
    save("cartographer", mira, manifest=manifest)

    base = {"walk": hero["walk"], "idle": hero["idle"]}
    npcs = {
        # Elder Elian: white hair cut short, long beard, earthy robe.
        "elder": dict(colors={RED_DARK: (92, 70, 48), RED_MID: (128, 98, 66), RED_LIGHT: (176, 140, 92), MAUVE: (60, 48, 40)},
                      trim=True, ahoge=False, beard=((246, 246, 236), (200, 204, 206)), fill=((92, 70, 48), (128, 98, 66))),
        # Toren the hunter: brown hair, forest greens.
        "hunter": dict(colors={HAIR_LIGHT: (150, 98, 56), HAIR_SHADE: (104, 66, 40), RED_DARK: (46, 72, 40),
                               RED_MID: (70, 104, 52), RED_LIGHT: (140, 120, 70), MAUVE: (50, 44, 30)},
                       trim=True, ahoge=False, fill=((46, 72, 40), (70, 104, 52))),
        # Dorn the miner: black hair, red beard, ochre work clothes.
        "miner": dict(colors={HAIR_LIGHT: (60, 56, 64), HAIR_SHADE: (36, 34, 42), RED_DARK: (120, 80, 30),
                              RED_MID: (168, 116, 44), RED_LIGHT: (214, 160, 70), MAUVE: (70, 50, 30)},
                      trim=True, ahoge=False, beard=((176, 82, 40), (130, 56, 30)), fill=((120, 80, 30), (168, 116, 44))),
        # Bran the merchant: chestnut hair, plum coat.
        "merchant": dict(colors={HAIR_LIGHT: (176, 112, 64), HAIR_SHADE: (124, 74, 46), RED_DARK: (78, 40, 84),
                                 RED_MID: (112, 62, 120), RED_LIGHT: (170, 110, 60), MAUVE: (54, 34, 56)},
                         trim=True, ahoge=False, fill=((78, 40, 84), (112, 62, 120))),
        # Archivist Orien: a ghost of a Keeper, pale blue and see-through.
        "archivist": dict(colors={HAIR_LIGHT: (236, 252, 255), HAIR_SHADE: (180, 220, 240), RED_DARK: (90, 150, 200),
                                  RED_MID: (140, 196, 232), RED_LIGHT: (200, 240, 255), SKIN_LIGHT: (222, 244, 255),
                                  SKIN_SHADE: (170, 206, 230), INK: (50, 90, 140), MAUVE: (90, 130, 170)},
                          trim=True, ahoge=False, beard=((240, 250, 255), (190, 220, 240)), alpha=0.85,
                          fill=((90, 150, 200), (140, 196, 232))),
        # Forest shaman: green hood of hair, bark robe, bone charms.
        "shaman": dict(colors={HAIR_LIGHT: (88, 120, 66), HAIR_SHADE: (58, 84, 48), RED_DARK: (70, 52, 36),
                               RED_MID: (104, 78, 50), RED_LIGHT: (214, 206, 170), MAUVE: (40, 34, 26),
                               SKIN_LIGHT: (200, 220, 170), SKIN_SHADE: (150, 176, 120), GOLD: (236, 226, 190)}, ahoge=False),
        # Vail's shade: a violet, half-transparent echo of him.
        "shade": dict(colors={HAIR_LIGHT: (150, 120, 210), HAIR_SHADE: (104, 80, 168), RED_DARK: (44, 30, 80),
                              RED_MID: (70, 50, 120), RED_LIGHT: (200, 170, 255), MAUVE: (30, 20, 50),
                              SKIN_LIGHT: (96, 80, 140), SKIN_SHADE: (70, 56, 110), INK: (20, 10, 40), GOLD: (230, 210, 255)},
                      ahoge=False, alpha=0.88),
        # Settlers found around the world (data/settlement.json).
        "settler_woodcutter": dict(colors={HAIR_LIGHT: (196, 120, 60), HAIR_SHADE: (140, 80, 40), RED_DARK: (120, 36, 30),
                                           RED_MID: (168, 60, 44), RED_LIGHT: (90, 110, 60), MAUVE: (60, 40, 30)},
                                   trim=True, ahoge=False, beard=((196, 120, 60), (140, 80, 40)), fill=((120, 36, 30), (168, 60, 44))),
        "settler_fisher": dict(colors={HAIR_LIGHT: (220, 220, 214), HAIR_SHADE: (170, 172, 170), RED_DARK: (40, 70, 96),
                                       RED_MID: (60, 104, 136), RED_LIGHT: (220, 190, 90), MAUVE: (40, 50, 60)},
                               trim=True, ahoge=False, beard=((230, 230, 224), (180, 180, 176)), fill=((40, 70, 96), (60, 104, 136))),
        # Gunhild, master smith of the Stone Pass: copper hair, leather apron.
        "smith_master": dict(colors={HAIR_LIGHT: (214, 120, 60), HAIR_SHADE: (160, 80, 40), RED_DARK: (70, 50, 36),
                                     RED_MID: (104, 76, 52), RED_LIGHT: (190, 190, 200), MAUVE: (50, 36, 28)}, ahoge=False),
        # Skeletons of the ruins: bone-white, bald, in grey rags.
        "skeleton": dict(colors={HAIR_LIGHT: (232, 228, 210), HAIR_SHADE: (190, 186, 170), RED_DARK: (52, 50, 54),
                                 RED_MID: (80, 76, 80), RED_LIGHT: (120, 116, 110), SKIN_LIGHT: (236, 232, 214),
                                 SKIN_SHADE: (196, 190, 170), MAUVE: (40, 38, 40), GOLD: (150, 146, 130), INK: (30, 20, 20)},
                         trim=True, ahoge=False, fill=((52, 50, 54), (80, 76, 80))),
        # The Crypt Lord: a hooded Keeper gone wrong, green-black and gold.
        "crypt_lord": dict(colors={HAIR_LIGHT: (60, 90, 70), HAIR_SHADE: (36, 58, 46), RED_DARK: (24, 34, 30),
                                   RED_MID: (40, 56, 46), RED_LIGHT: (150, 230, 160), MAUVE: (16, 22, 20),
                                   SKIN_LIGHT: (170, 190, 170), SKIN_SHADE: (120, 140, 120), GOLD: (220, 190, 90)}, ahoge=False),
        # Moren the lighthouse keeper: grey beard, navy coat.
        "keeper": dict(colors={HAIR_LIGHT: (200, 200, 196), HAIR_SHADE: (150, 150, 150), RED_DARK: (30, 40, 70),
                               RED_MID: (46, 62, 104), RED_LIGHT: (220, 180, 80), MAUVE: (30, 34, 50)},
                       trim=True, ahoge=False, beard=((210, 210, 206), (160, 160, 160)), fill=((30, 40, 70), (46, 62, 104))),
        # Ignat, the hermit of the Ashen Waste: ash-grey hair and beard, charcoal robe, ember trim.
        "ash_hermit": dict(colors={HAIR_LIGHT: (176, 170, 164), HAIR_SHADE: (128, 122, 118), RED_DARK: (44, 36, 36),
                                   RED_MID: (70, 58, 56), RED_LIGHT: (230, 120, 50), MAUVE: (30, 24, 24)},
                           trim=True, ahoge=False, beard=((190, 184, 178), (140, 134, 128)), fill=((44, 36, 36), (70, 58, 56))),
        # Ash cultists: black hoods, crimson robes, burning eyes.
        "ash_cultist": dict(colors={HAIR_LIGHT: (40, 30, 32), HAIR_SHADE: (24, 18, 20), RED_DARK: (90, 20, 20),
                                    RED_MID: (140, 34, 28), RED_LIGHT: (255, 150, 60), MAUVE: (40, 14, 14),
                                    SKIN_LIGHT: (150, 120, 110), SKIN_SHADE: (110, 86, 80), INK: (255, 120, 40), GOLD: (255, 170, 70)},
                            ahoge=False),
        # Aella, the first Keeper: a pale-gold ghost in a faded white robe.
        "aella": dict(colors={HAIR_LIGHT: (255, 246, 214), HAIR_SHADE: (226, 206, 150), RED_DARK: (176, 160, 120),
                              RED_MID: (220, 208, 170), RED_LIGHT: (255, 236, 160), SKIN_LIGHT: (250, 240, 226),
                              SKIN_SHADE: (220, 200, 180), MAUVE: (150, 136, 110), GOLD: (255, 230, 140)},
                      ahoge=False, alpha=0.85),
        # Soren, herald of the reborn Keeper order: dark hair, white-and-sky-blue robe, gold trim.
        "herald": dict(colors={HAIR_LIGHT: (70, 60, 80), HAIR_SHADE: (44, 36, 54), RED_DARK: (60, 110, 170),
                               RED_MID: (220, 230, 244), RED_LIGHT: (255, 220, 120), MAUVE: (40, 60, 96),
                               GOLD: (255, 214, 110)}, trim=True, ahoge=False),
        # Olm, the night guard: dark hair, steel-grey coat, red sash.
        "guard": dict(colors={HAIR_LIGHT: (96, 70, 52), HAIR_SHADE: (64, 46, 34), RED_DARK: (150, 40, 40),
                              RED_MID: (120, 130, 150), RED_LIGHT: (190, 200, 214), MAUVE: (60, 66, 84),
                              GOLD: (200, 200, 210)}, trim=True, ahoge=False),
        # Neya, the caravan trader: chestnut hair, orange travel coat.
        "caravaner": dict(colors={HAIR_LIGHT: (170, 96, 50), HAIR_SHADE: (120, 64, 34), RED_DARK: (150, 80, 30),
                                  RED_MID: (220, 140, 60), RED_LIGHT: (250, 200, 120), MAUVE: (90, 60, 40),
                                  GOLD: (240, 200, 90)}, trim=False),
        # Vail: long white hair, violet Keeper robes.
        "vail": dict(colors={RED_DARK: (58, 40, 98), RED_MID: (92, 66, 150), RED_LIGHT: (176, 132, 236), MAUVE: (40, 30, 60),
                             GOLD: (210, 180, 255)}, ahoge=False),
    }
    for npc_id, spec in npcs.items():
        save(npc_id, {k: make_variant(v, **spec) for k, v in base.items()}, manifest=manifest)

    # Ilara of the grove: the companion's frame in moss green.
    comp_base = {"walk": mira["walk"], "idle": mira["idle"]}
    ilara = {}
    for k, v in comp_base.items():
        a = v.copy()
        r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
        warm = (a[:, :, 3] > 0) & (r > g + 30) & (r > b + 30) & ~mask(a, SKIN_LIGHT, SKIN_SHADE)
        a[warm, 0] = (g[warm] * 0.7).astype(np.uint8)
        a[warm, 1] = np.clip(r[warm] * 0.75, 0, 255).astype(np.uint8)
        a[warm, 2] = np.clip(b[warm] * 0.9 + 20, 0, 255).astype(np.uint8)
        ilara[k] = a
    save("grove_warden", ilara, manifest=manifest)

    # Martha the cook: the companion's frame with an apron-white dress.
    marta = {}
    for k, v in comp_base.items():
        a = v.copy()
        r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
        warm = (a[:, :, 3] > 0) & (r > g + 30) & (r > b + 30) & ~mask(a, SKIN_LIGHT, SKIN_SHADE)
        lum = (r * 0.5 + g * 0.35 + b * 0.15)
        a[warm, 0] = np.clip(lum[warm] * 1.05 + 70, 0, 255).astype(np.uint8)
        a[warm, 1] = np.clip(lum[warm] * 1.0 + 64, 0, 255).astype(np.uint8)
        a[warm, 2] = np.clip(lum[warm] * 0.9 + 50, 0, 255).astype(np.uint8)
        marta[k] = a
    save("settler_cook", marta, manifest=manifest)

    # Pack NPCs with their own idle animation (one direction, at their table).
    save("blacksmith", {"idle": single_row("Blacksmith/Idle Working.png", 8, 32)}, 32, 32, manifest)
    save("herbalist", {"idle": single_row("Herbalist/Idle Mixing.png", 8, 25)}, 25, 30, manifest)
    save("alchemist", {"idle": single_row("Potion Maker/Idle Research.png", 19, 25)}, 25, 33, manifest)

    build_decor()
    import village
    village.build(ROOT)
    village.build_ui(ROOT)
    village.build_gathering(ROOT)
    village.build_coast(ROOT)
    village.build_dungeon(ROOT)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
