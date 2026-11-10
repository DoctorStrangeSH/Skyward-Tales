#!/usr/bin/env python3
"""Homestead and seasons art (stage 21, step 4) from the owner's new sprites.

    python3 tools/art/homestead_art.py

  world_hd/village_mill_1/2.png, village_greenhouse_1/2.png — buildings;
  world_hd/props/mill_wheel.png (8x6 frames), mill_splash.png (4x3 frames);
  world_hd/props/farm_soil(_wet).png, crop_<kind>_<0..2>.png — garden beds;
  world_hd/season_<spring|autumn|winter>_tree_<0|1>.png and
  world_hd/props/season_<...>_detail.png — the seasons (scripts/seasons.gd).
All at the HD scale (shown at 1/K), anchors in assets/art_manifest.json.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

OUT = sprites.OUT
K = sprites.K
NS = sprites.NS

BUILDINGS = {
    "village_mill_1": ("green_reach/watermill/watermill_building", 74),
    "village_mill_2": ("green_reach/watermill/watermill_building", 74),
    "village_greenhouse_1": ("farm/greenhouse/greenhouse", 84),
    "village_greenhouse_2": ("farm/greenhouse/greenhouse", 92),
    "season_spring_tree_0": ("seasons/decor/spring_tree", 76),
    "season_spring_tree_1": ("hd/greenreach/nature/tree_spring", 70),
    "season_autumn_tree_0": ("seasons/decor/autumn_tree", 76),
    "season_autumn_tree_1": ("hd/greenreach/nature/tree_autumn", 70),
    "season_winter_tree_0": ("seasons/decor/winter_tree", 76),
    "season_winter_tree_1": ("hd/greenreach/nature/tree_winter", 70),
}
PROPS = {
    "farm_soil": ("farm/decor/tilled_soil", 34),
    "farm_soil_wet": ("farm/decor/tilled_soil_wet", 34),
    "crop_wheat_0": ("farm/decor/wheat_sprout", 26),
    "crop_wheat_1": ("farm/decor/wheat_green", 28),
    "crop_wheat_2": ("farm/decor/wheat_ripe", 30),
    "crop_carrot_0": ("farm/decor/carrot_sprout", 26),
    "crop_carrot_1": ("farm/decor/carrot_young", 28),
    "crop_carrot_2": ("farm/decor/carrot_mature", 30),
    "crop_berry_0": ("farm/berry_patch/crop/raspberry_picked", 22),
    "crop_berry_1": ("farm/berry_patch/crop/raspberry_unripe", 28),
    "crop_berry_2": ("farm/berry_patch/crop/raspberry_ripe", 30),
    "farm_trough": ("farm/decor/irrigation_trough", 34),
    "farm_barrel": ("farm/greenhouse/rain_barrel", 15),
    "farm_sheaf": ("farm/decor/wheat_sheaf", 18),
    "farm_bench": ("farm/greenhouse/potting_bench", 26),
    "season_spring_detail": ("seasons/decor/spring_ground_detail", 24),
    "season_autumn_detail": ("seasons/decor/autumn_ground_detail", 24),
    "season_winter_detail": ("seasons/decor/winter_ground_detail", 26),
}


def sheet(rel: str, cols: int, rows: int, cell: int) -> Image.Image:
    src = pack.image(NS % rel)
    w, h = src.width // cols, src.height // rows
    out = Image.new("RGBA", (cell * cols, round(cell * h / w) * rows))
    ch = out.height // rows
    for r in range(rows):
        for c in range(cols):
            frame = src.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)).resize((cell, ch), Image.LANCZOS)
            out.paste(frame, (c * cell, r * ch))
    return out


def main() -> int:
    manifest_path = pack.ROOT / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    (OUT / "props").mkdir(parents=True, exist_ok=True)
    for name, (rel, width) in BUILDINGS.items():
        img, origin = sprites.make(NS % rel, width)
        img.save(OUT / f"{name}.png", optimize=True)
        art[f"world_hd/{name}.png"] = {"size": [img.width, img.height], "origin": list(origin), "scale": 1.0 / K}
    for name, (rel, width) in PROPS.items():
        img, origin = sprites.make(NS % rel, width)
        if name.startswith("farm_soil") or name.endswith("_detail"):
            origin = (img.width // 2, img.height // 2)
        img.save(OUT / "props" / f"{name}.png", optimize=True)
        art[f"world_hd/props/{name}.png"] = {"size": [img.width, img.height], "origin": list(origin), "scale": 1.0 / K}
    # The mill wheel keeps the building's scale: 240 px of source = 74 px.
    cell = round(88 * 74 * K / 240)
    sheet("green_reach/watermill/watermill_wheel", 8, 6, cell).save(OUT / "props" / "mill_wheel.png", optimize=True)
    sheet("green_reach/watermill/watermill_splash", 4, 3, cell).save(OUT / "props" / "mill_splash.png", optimize=True)
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("homestead art:", len(BUILDINGS) + len(PROPS) + 2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
