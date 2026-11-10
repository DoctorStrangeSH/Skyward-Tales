"""The Foresters' Lodge from inside (region "guild_lodge"): one room with an
oak floor. Walls, furniture and people are placed by scripts/forest_guild.gd
(ROOM there matches this file). Also plants a small grove of trees for felling
around the cottage in Greenreach.

    python3 tools/lodge_layout.py && python3 tools/art/hd/build_hd.py guild_lodge
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [640, 400]
ROOM = [192, 144, 256, 160]
GROVE = [[1548, 452], [1694, 468], [1706, 574], [1538, 566]]


def main() -> int:
    region = {
        "name": "Дом лесничих",
        "map_color": [0.6, 0.42, 0.24],
        "level": 1,
        "enemy_power": 1.0,
        "hidden": True,
        "peaceful": True,
        "npcs": [{"id": "forester", "name": "Орвин, старший лесничий", "position": [ROOM[0] + 150, ROOM[1] + 52], "look": "settler_woodcutter"}],
        "chests": [], "herbs": [], "story_objects": [], "enemies": [], "gates": [], "secrets": {},
        "terrain": {"size": SIZE, "style": "crypt", "art_style": "lodge", "rooms": [ROOM], "trails": [], "ponds": [],
                    "trees": [], "props": [], "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["guild_lodge"] = region
    # A clearing in front of the cottage.
    trees = regions["greenreach"]["terrain"]["trees"]
    trees[:] = [t for t in trees if not (1530 <= t[0] <= 1715 and 470 <= t[1] <= 650)]
    bushes = regions["greenreach"]["terrain"]["bushes"]
    bushes[:] = [b for b in bushes if not (1560 <= b[0] <= 1690 and 480 <= b[1] <= 600)]
    gather = regions["greenreach"]["gather"]
    have = {tuple(e["position"]) for e in gather}
    for spot in GROVE:
        if tuple(spot) not in have:
            gather.append({"kind": "wood", "position": spot})
    path.write_text(jsonfmt.dumps(regions))
    print("guild_lodge: room", ROOM)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
