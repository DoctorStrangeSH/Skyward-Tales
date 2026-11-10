"""The Old Adit (region "old_adit"): an entry cave, a railed tunnel, the
copper hall, and two branches behind cave-ins. Rubble, the cart, the timber
and the guardian are placed by scripts/old_adit.gd (same coordinates).

    python3 tools/adit_layout.py && python3 tools/art/hd/build_hd.py old_adit
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [1232, 656]
ENTRY = [64, 368, 240, 176]
TUNNEL = [304, 416, 400, 64]
COPPER_HALL = [704, 320, 224, 256]
EAST_TUNNEL = [928, 416, 112, 64]
DEEP_HALL = [1040, 288, 128, 288]
NORTH_TUNNEL = [784, 176, 64, 144]
GEODE_HALL = [688, 64, 256, 112]


def main() -> int:
    rooms = [ENTRY, TUNNEL, COPPER_HALL, EAST_TUNNEL, DEEP_HALL, NORTH_TUNNEL, GEODE_HALL]
    gather = [
        {"kind": "copper", "position": [100, 400]}, {"kind": "stone", "position": [270, 400]},
        {"kind": "copper", "position": [730, 350]}, {"kind": "copper", "position": [900, 350]},
        {"kind": "copper", "position": [730, 550]}, {"kind": "iron", "position": [900, 550]},
        {"kind": "copper", "position": [1066, 320]}, {"kind": "copper", "position": [1140, 420]},
        {"kind": "iron", "position": [1066, 540]}, {"kind": "iron", "position": [1140, 540]},
        {"kind": "amethyst", "position": [712, 96]}, {"kind": "amethyst", "position": [916, 96]}, {"kind": "amethyst", "position": [816, 84]},
    ]
    enemies = [
        {"kind": "bat", "position": [420, 440]}, {"kind": "slime", "position": [560, 452]},
        {"kind": "bat", "position": [820, 380]}, {"kind": "skeleton", "position": [860, 500]}, {"kind": "slime", "position": [760, 470]},
        {"kind": "skeleton", "position": [1100, 380]}, {"kind": "bat", "position": [1110, 500]},
    ]
    region = {
        "name": "Старая штольня",
        "map_color": [0.5, 0.36, 0.26],
        "level": 3,
        "enemy_power": 1.0,
        "hidden": True,
        "npcs": [], "chests": [], "herbs": [], "story_objects": [], "enemies": enemies, "gates": [], "secrets": {},
        "gather": gather,
        "terrain": {"size": SIZE, "style": "crypt", "art_style": "mine", "rooms": rooms, "trails": [], "ponds": [],
                    "trees": [], "props": [], "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["old_adit"] = region
    path.write_text(jsonfmt.dumps(regions))
    print("old_adit:", len(rooms), "rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
