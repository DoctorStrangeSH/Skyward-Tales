"""32x32 icons for the package-C gear: shields, rings, earrings, cloaks.

Drawn in code (the owner's asset pack is being reworked, so nothing is taken
from it). Light from the top left, a coloured outline like the other icons.

    python3 tools/art/gear_icons.py   (writes assets/icons/<id>.png)
"""
from __future__ import annotations

import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from pixel import Canvas, hex_color, ramp  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = hex_color("#241a30")
WOOD = ramp("#e6b678", "#b9844f", "#87593a", "#553422")
IRON = ramp("#f2f5f6", "#bcc5cc", "#828c9c", "#4f5866")
GOLD = ramp("#fff6c0", "#ffd45c", "#e0962e", "#8a4a22")
COPPER = ramp("#ffd9b0", "#e8995a", "#b0623a", "#6a3424")
SILVER = ramp("#ffffff", "#d8e0ea", "#9aa6b8", "#5c667a")


def _shade(base, x: float, y: float, cx: float, cy: float, r: float):
    """Pick a ramp tone from the top-left light."""
    d = ((x - cx) + (y - cy)) / max(1.0, r)
    if d < -0.7:
        return base[0]
    if d < 0.2:
        return base[1]
    if d < 0.85:
        return base[2]
    return base[3] if len(base) > 3 else base[2]


def _shield_mask(x: int, y: int, kind: str) -> bool:
    if kind == "round":
        return (x - 15.5) ** 2 + (y - 15.5) ** 2 <= 12.5 ** 2
    # Heater shield: straight top, round sides, pointed bottom.
    if y < 4 or y > 29:
        return False
    if y <= 16:
        return 4 <= x <= 27
    half = 12 * math.sqrt(max(0.0, 1 - ((y - 16) / 13.5) ** 2))
    return abs(x - 15.5) <= half


def shield(face, rim, kind: str = "heater", boss=None, cross=None, planks: bool = False) -> Canvas:
    c = Canvas(32, 32)
    for y in range(32):
        for x in range(32):
            if not _shield_mask(x, y, kind):
                continue
            edge = not all(_shield_mask(x + dx, y + dy, kind) for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)))
            tone = _shade(rim if edge else face, x, y, 15.5, 15.5, 14)
            if planks and not edge and x % 6 == 0:
                tone = face[3] if len(face) > 3 else face[2]
            c.put(x, y, tone)
    if cross is not None:
        for y in range(6, 27):
            for x in (15, 16):
                if c.alpha(x, y):
                    c.put(x, y, cross[1] if x == 15 else cross[2])
        for x in range(6, 26):
            for y in (13, 14):
                if c.alpha(x, y):
                    c.put(x, y, cross[1] if y == 13 else cross[2])
    if boss is not None:
        c.ellipse(15.5, 14.5, 3.4, 3.4, boss[2])
        c.ellipse(15.0, 14.0, 2.4, 2.4, boss[1])
        c.put(14, 13, boss[0])
    c.outline(OUT)
    return c


def ring(band, gem=None) -> Canvas:
    c = Canvas(32, 32)
    cx, cy = 15.5, 18.5
    for y in range(32):
        for x in range(32):
            d = math.hypot((x - cx) / 1.0, (y - cy) / 0.82)
            if 6.2 <= d <= 9.4:
                c.put(x, y, _shade(band, x, y, cx, cy, 9))
    if gem is not None:
        c.ellipse(15.5, 9.5, 4.6, 4.2, gem[2])
        c.ellipse(15.0, 9.0, 3.4, 3.0, gem[1])
        c.put(13, 8, gem[0])
        c.put(14, 7, gem[0])
        for x in (11, 20):
            c.put(x, 11, band[1])
    c.outline(OUT)
    return c


def earrings(metal, gem) -> Canvas:
    c = Canvas(32, 32)
    for ox in (9, 22):
        # Hook.
        for a in range(0, 200, 12):
            t = math.radians(a + 160)
            c.put(int(round(ox + 2.6 * math.cos(t))), int(round(7 + 2.6 * math.sin(t))), metal[1])
        c.vline(ox, 9, 14, metal[2])
        # Drop.
        for y in range(14, 27):
            w = 3.6 * math.sin(math.pi * (y - 13) / 14.0)
            for x in range(ox - 5, ox + 6):
                if abs(x - ox) <= w:
                    c.put(x, y, _shade(gem, x, y, ox, 20, 4))
        c.put(ox - 1, 17, gem[0])
    c.outline(OUT)
    return c


def cloak(cloth, clasp, hood: bool = False) -> Canvas:
    c = Canvas(32, 32)
    dark = cloth[3] if len(cloth) > 3 else cloth[2]
    for y in range(6, 30):
        # Rounded shoulders, then the cloth falls and flares a little.
        if y < 11:
            spread = 6.0 + 4.0 * math.sqrt(max(0.0, (y - 5) / 5.0))
        else:
            spread = 10.0 + (y - 11) * 0.22
        for x in range(32):
            if abs(x - 15.5) > spread:
                continue
            tone = _shade(cloth, x, y, 15.5, 17, 12)
            # Vertical folds.
            if y > 12 and (x - 3) % 5 == 0:
                tone = dark
            # The opening down the front.
            if y > 17 and abs(x - 15.5) < 0.6 + (y - 17) * 0.1:
                tone = (0, 0, 0, 0)
            c.put(x, y, tone)
    for x in range(4, 28):
        if (x // 2) % 2 == 0 and c.alpha(x, 29):
            c.put(x, 29, (0, 0, 0, 0))
    if hood:
        c.ellipse(15.5, 6.5, 4.8, 3.6, cloth[1])
        c.ellipse(15.5, 7.4, 3.0, 2.0, dark)
    c.ellipse(15.5, 12.0, 1.8, 1.8, clasp[1])
    c.put(15, 11, clasp[0])
    c.outline(OUT)
    return c


def build() -> dict[str, Canvas]:
    ember = ramp("#fff0a0", "#ff9a3c", "#c8352e")
    frost = ramp("#f0fdff", "#7fd4ff", "#3a6fc0")
    storm = ramp("#f6eaff", "#b48aff", "#6a4ac8")
    life = ramp("#e8ffd8", "#6ad06a", "#2f8a4a")
    ruby = ramp("#ffd0d8", "#e8485a", "#8a2032")
    return {
        "wooden_shield": shield(WOOD, IRON, "round", boss=IRON, planks=True),
        "iron_shield": shield(ramp("#c89a68", "#9a6a40", "#6e4a2c", "#4a2e1c"), IRON, "heater", boss=IRON, cross=IRON),
        "guard_shield": shield(ramp("#9ac8ff", "#4a7ad0", "#2e4e94", "#1e2e60"), GOLD, "heater", cross=GOLD),
        "sky_aegis": shield(ramp("#f4fcff", "#9ce0ff", "#4a9ad8", "#2a5a94"), GOLD, "heater", boss=ramp("#ffffff", "#c8f4ff", "#5fd6ff")),
        "copper_ring": ring(COPPER),
        "ember_ring": ring(GOLD, ember),
        "frost_ring": ring(SILVER, frost),
        "storm_ring": ring(SILVER, storm),
        "vigor_ring": ring(GOLD, life),
        "duelist_ring": ring(SILVER, ruby),
        "silver_earrings": earrings(SILVER, ramp("#ffffff", "#c8e8ff", "#7aa8d8")),
        "wind_earrings": earrings(SILVER, ramp("#f0fffa", "#8ae8d0", "#3a9a8a")),
        "sage_earrings": earrings(GOLD, storm),
        "travel_cloak": cloak(ramp("#d8b890", "#a07a52", "#74543a", "#4a3424"), IRON, hood=True),
        "hunter_cloak": cloak(ramp("#b8d090", "#6a8a4a", "#4a6230", "#2e3e1e"), GOLD),
    }


def main() -> int:
    folder = ROOT / "assets" / "icons"
    manifest_path = ROOT / "assets" / "art_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for item_id, canvas in build().items():
        canvas.save(folder / f"{item_id}.png")
        manifest[f"icons/{item_id}.png"] = {"size": [canvas.w, canvas.h]}
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n")
    print("gear icons written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
