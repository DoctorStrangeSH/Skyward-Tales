"""The Tower of Trials (region "trial_tower"): one stone hall that serves
every floor. Foes, the lever, the coffer, the altar and the stairs are placed
by scripts/trial_tower.gd; this script only lays out the hall.

    python3 tools/tower_layout.py && python3 tools/art/hd/build_hd.py trial_tower
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [544, 432]
HALL = [64, 96, 416, 272]


def main() -> int:
    x, y, w, h = HALL
    props = [{"kind": "crypt_torch", "position": [x + 40 + i * 112, y + 12]} for i in range(4)]
    region = {
        "name": "Башня испытаний",
        "map_color": [0.42, 0.3, 0.6],
        "level": 1,
        "enemy_power": 1.0,
        "hidden": True,
        "npcs": [], "chests": [], "herbs": [], "story_objects": [], "enemies": [],
        "gates": [{"target": "greenreach", "position": [x + w // 2, y + h - 14], "arrival": [1078, 498], "label": "Выход из башни"}],
        "secrets": {},
        "terrain": {"size": SIZE, "style": "crypt", "rooms": [HALL], "trails": [], "ponds": [],
                    "trees": [], "props": props, "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["trial_tower"] = region
    path.write_text(jsonfmt.dumps(regions))
    print("trial_tower: hall", HALL)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
