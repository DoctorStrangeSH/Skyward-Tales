#!/usr/bin/env python3
"""Art of the Foresters' Lodge (stage 21, step 8) from the owner's sprites.

    python3 tools/art/guild_art.py

  world_hd/props/lodge_*.png — the cottage, its yard, the room's walls and
      furniture (anchors in the manifest);
  world_hd/props/lodge_hearth.png (4x2 frames), lodge_candle.png (4x2),
      lodge_lantern.png (4x2) — animated;
  world_hd/props/tree_<oak|birch>_<ready|cut|young>.png — felled trees that
      grow back (one canvas and one anchor for the three states);
  world_hd/props/vein_<ready|cut>.png — an ore vein and its worked-out look.
Used by scripts/forest_guild.gd and scripts/gather_node.gd.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

W = "woodland_guild/"
PROPS = {
    "lodge_cottage": (W + "exterior/workshop_cottage", 86),
    "lodge_firewood": (W + "exterior/covered_firewood", 28),
    "lodge_fence": (W + "exterior/fence_segment", 34),
    "lodge_fern": (W + "exterior/fern_cluster", 20),
    "lodge_bluebells": (W + "exterior/bluebells", 16),
    "lodge_flowers": (W + "exterior/meadow_flowers", 28),
    "lodge_wall": (W + "interior/rear_wall_straight", 64),
    "lodge_wall_window": (W + "interior/rear_wall_window", 64),
    "lodge_wall_west": (W + "interior/side_wall_west", 20),
    "lodge_wall_east": (W + "interior/side_wall_east", 20),
    "lodge_wall_front": (W + "interior/front_wall_cutaway", 64),
    "lodge_threshold": (W + "interior/door_threshold", 40),
    "lodge_bench": (W + "interior/carpenter_bench", 46),
    "lodge_table": (W + "interior/dining_table", 34),
    "lodge_bed": (W + "interior/single_bed", 28),
    "lodge_stool": (W + "interior/small_stool", 14),
    "lodge_chest": (W + "interior/storage_chest", 24),
    "lodge_shelf": (W + "interior/supply_shelf", 32),
    "lodge_rug": (W + "interior/woven_rug", 48),
    "vein_ready": (W + "resources/vein_intact", 34),
    "vein_cut": (W + "resources/vein_depleted", 34),
}
# Flat on the floor / hung by the top edge.
CENTRED = ("lodge_rug", "lodge_threshold")
SHEETS = {
    "lodge_hearth": ("interiors/animated_fireplace/fireplace_burning", 4, 2, 44),
    "lodge_candle": ("interiors/lanterns_and_candles/table_candle_burning", 4, 2, 14),
    "lodge_lantern": ("interiors/lanterns_and_candles/wall_lantern_burning", 4, 2, 16),
}
TREE_WIDTH = 150


def src(rel: str) -> Image.Image:
    return pack.image(sprites.NS % rel).convert("RGBA")


def main() -> int:
    K = sprites.K
    manifest_path = pack.ROOT / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    out = sprites.OUT / "props"
    for name, (rel, width) in PROPS.items():
        img, origin = sprites.make(sprites.NS % rel, width)
        if name in CENTRED:
            origin = (img.width // 2, img.height // 2)
        if name.startswith("lodge_wall"):
            origin = (img.width // 2, img.height)
        img.save(out / f"{name}.png", optimize=True)
        art[f"world_hd/props/{name}.png"] = {"size": [img.width, img.height], "origin": list(origin), "scale": 1.0 / K}
    for name, (rel, cols, rows, width) in SHEETS.items():
        sheet = src(rel)
        w, h = sheet.width // cols, sheet.height // rows
        cw = width * K
        ch = round(h * cw / w)
        res = Image.new("RGBA", (cw * cols, ch * rows))
        for r in range(rows):
            for c in range(cols):
                res.paste(sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)).resize((cw, ch), Image.LANCZOS), (c * cw, r * ch))
        res.save(out / f"{name}.png", optimize=True)
    # Trees: the three states share the canvas, so the stump stays in place.
    for species in ("oak", "birch"):
        cut = src(W + f"resources/{species}_cut")
        scale = TREE_WIDTH * K / cut.width
        size = (round(cut.width * scale), round(cut.height * scale))
        alpha = np.asarray(cut.resize(size, Image.LANCZOS))[:, :, 3]
        ys, xs = np.nonzero(alpha > 128)
        origin = [int(xs.mean()), int(ys.max())]
        for state, source in (("ready", "intact"), ("cut", "cut"), ("young", "young")):
            img = src(W + f"resources/{species}_{source}").resize(size, Image.LANCZOS)
            img.save(out / f"tree_{species}_{state}.png", optimize=True)
            art[f"world_hd/props/tree_{species}_{state}.png"] = {"size": list(size), "origin": origin, "scale": 1.0 / K}
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("guild art:", len(PROPS) + len(SHEETS) + 6)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
