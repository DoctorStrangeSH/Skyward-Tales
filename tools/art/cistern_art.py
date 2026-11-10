#!/usr/bin/env python3
"""Art of the Flooded Cistern (stage 21, step 6) from the owner's sprites.

    python3 tools/art/cistern_art.py

Writes assets/world_hd/props/cistern_*.png (drain plate, lantern, rubble,
grate, column, pots, sarcophagus, torch) with anchors in the manifest and
assets/world_hd/props/cistern_water.png — the seamless water tile.
Used by scripts/cistern.gd.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

C = "dungeons/flooded_cistern/"
D = "dungeons/decor/"
PROPS = {
    "cistern_plate": (D + "pressure_plate", 30),
    "cistern_lantern": (C + "lantern_pier", 14),
    "cistern_rubble": (C + "fern_rubble", 24),
    "cistern_grate": (C + "wall_grate", 56),
    "cistern_column": (D + "broken_column", 22),
    "cistern_pots": (D + "pottery_and_bone", 24),
    "cistern_sarcophagus": (D + "sarcophagus", 38),
    "cistern_torch": (D + "stone_torch", 12),
    "cistern_arch": ("dungeons/passages/dungeon_stone_arch", 48),
}
FLAT = ("cistern_plate",)


def main() -> int:
    manifest_path = pack.ROOT / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    out = sprites.OUT / "props"
    for name, (rel, width) in PROPS.items():
        img, origin = sprites.make(sprites.NS % rel, width)
        if name in FLAT:
            origin = (img.width // 2, img.height // 2)
        img.save(out / f"{name}.png", optimize=True)
        art[f"world_hd/props/{name}.png"] = {"size": [img.width, img.height], "origin": list(origin), "scale": 1.0 / sprites.K}
    water = pack.image(sprites.NS % (C + "water_loop")).convert("RGB")
    water.crop((0, 0, 256, 256)).save(out / "cistern_water.png", optimize=True)
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("cistern art:", len(PROPS) + 1)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
