"""The Starfall Isle (region "starfall_isle", этап 24): an island that rises
above the clouds only on the Night of Starfall (the calendar's festival,
8th day of winter); the sky ship «Ветрокрыл» is the only way there. Falling
stars and the Star Guardian are run by scripts/starfall_isle.gd.

    python3 tools/starfall_layout.py && python3 tools/art/hd/build_hd.py starfall_isle
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

REGION = {
    "name": "Звёздный остров",
    "map_color": [0.55, 0.6, 0.95],
    "level": 10,
    "enemy_power": 1.1,
    "hidden": True,
    "dock": [640, 720],
    "npcs": [],
    "chests": [
        {"id": "starfall_crater", "position": [300, 260], "gold": 160, "item": "starlight_essence", "amount": 1, "tier": "iron"},
    ],
    "herbs": [],
    "story_objects": [],
    "enemies": [
        {"kind": "wisp", "position": [420, 520]},
        {"kind": "wisp", "position": [860, 520]},
        {"kind": "wisp", "position": [980, 300]},
        {"kind": "shade", "position": [300, 420]},
    ],
    "gates": [],
    "secrets": {},
    "terrain": {
        "size": [1280, 864], "style": "sky", "edge_margin": 64,
        "trails": [[[640, 720], [640, 560], [640, 420]], [[640, 560], [420, 520], [300, 300]], [[640, 560], [880, 500], [1000, 300]]],
        "ponds": [{"circle": [640, 300, 46]}],
        "trees": [[180, 200], [1100, 180], [170, 620], [1110, 640], [400, 760], [880, 760]],
        "props": [],
        "blockers": [{"center": [640, 300], "size": [80, 76]}],
        "bushes": [],
    },
}


def main() -> int:
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["starfall_isle"] = REGION
    path.write_text(jsonfmt.dumps(regions))
    print("starfall_isle written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
