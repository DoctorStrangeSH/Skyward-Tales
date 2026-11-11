"""The heroine's house from inside (region "hero_home"): one snug room.
Walls, furniture and trophies are placed by scripts/hero_home.gd (ROOM there
matches this file).

    python3 tools/home_layout.py && python3 tools/art/hd/build_hd.py hero_home
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [640, 400]
ROOM = [192, 144, 256, 144]


def main() -> int:
    region = {
        "name": "Дом героини",
        "map_color": [0.7, 0.45, 0.3],
        "level": 1,
        "enemy_power": 1.0,
        "hidden": True,
        "peaceful": True,
        "npcs": [], "chests": [], "herbs": [], "story_objects": [], "enemies": [], "gates": [], "secrets": {},
        "terrain": {"size": SIZE, "style": "crypt", "art_style": "lodge", "rooms": [ROOM], "trails": [], "ponds": [],
                    "trees": [], "props": [], "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["hero_home"] = region
    path.write_text(jsonfmt.dumps(regions))
    print("hero_home: room", ROOM)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
