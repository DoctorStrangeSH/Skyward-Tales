#!/usr/bin/env python3
"""Art of the Tower of Trials (stage 21, step 5) from the owner's sprites.

    python3 tools/art/tower_art.py

Writes assets/world_hd/props/tower_*.png (gate, lever, coffer, altar,
stairs, checkpoint crystal, brazier, banner, floor sigil, amethysts) at the
HD scale with anchors in assets/art_manifest.json. Used by
scripts/trial_tower.gd.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

T = "tower_of_trials/"
PROPS = {
    "tower_gate_closed": (T + "decor/trial_gate_closed", 58),
    "tower_gate_open": (T + "decor/trial_gate_open", 58),
    "tower_lever": (T + "mechanisms/lever/lever_idle", 30),
    "tower_lever_pulled": (T + "mechanisms/lever/lever_pulled", 30),
    "tower_coffer": (T + "mechanisms/coffer/coffer_closed", 32),
    "tower_coffer_open": (T + "mechanisms/coffer/coffer_open", 32),
    "tower_altar": (T + "mechanisms/altar/altar_empty", 34),
    "tower_altar_charged": (T + "mechanisms/altar/altar_charged", 34),
    "tower_stairs": (T + "decor/stairs_up", 44),
    "tower_crystal": (T + "decor/checkpoint_crystal", 26),
    "tower_brazier": (T + "decor/rune_brazier", 22),
    "tower_banner": (T + "decor/trial_banner", 24),
    "tower_sigil": (T + "decor/floor_sigil", 72),
    "tower_amethyst": (T + "decor/amethyst_fragments", 22),
    "tower_medallion": (T + "star_observatory/compass_floor_medallion", 44),
    "tower_lectern": (T + "star_observatory/star_chart_lectern", 26),
}
FLAT = ("tower_sigil", "tower_medallion")


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
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("tower art:", len(PROPS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
