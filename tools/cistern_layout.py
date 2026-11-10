"""The Flooded Cistern (region "flooded_cistern"): halls joined by channels
that stand under water until the drain plates are pressed
(scripts/cistern.gd holds POOLS / PLATES in the same coordinates).

    python3 tools/cistern_layout.py && python3 tools/art/hd/build_hd.py flooded_cistern
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [1136, 832]
START = [80, 576, 272, 176]
CENTRE = [448, 480, 304, 272]
WEST = [352, 176, 304, 176]
EAST = [864, 480, 192, 272]
BOSS = [768, 96, 288, 288]
# Channels (flooded at first): centre→west, centre→east, west→boss.
CHANNELS = [[480, 352, 64, 128], [752, 576, 112, 64], [656, 224, 112, 64]]
LINK = [352, 624, 96, 64]


def main() -> int:
    rooms = [START, CENTRE, WEST, EAST, BOSS, LINK] + CHANNELS
    props = []
    for x, y, w, _h in (START, CENTRE, WEST, EAST, BOSS):
        props += [{"kind": "crypt_torch", "position": [x + 32, y + 12]}, {"kind": "crypt_torch", "position": [x + w - 32, y + 12]}]
    enemies = [
        {"kind": "slime", "position": [520, 560]}, {"kind": "bat", "position": [680, 540]}, {"kind": "crab", "position": [620, 690]},
        {"kind": "toad", "position": [430, 250]}, {"kind": "skeleton", "position": [580, 300]}, {"kind": "bat", "position": [500, 220]},
        {"kind": "crab", "position": [930, 560]}, {"kind": "toad", "position": [990, 680]}, {"kind": "skeleton", "position": [920, 700]},
    ]
    region = {
        "name": "Старая цистерна",
        "map_color": [0.2, 0.5, 0.5],
        "level": 4,
        "enemy_power": 1.0,
        "hidden": True,
        "npcs": [], "chests": [], "herbs": [], "story_objects": [], "enemies": enemies,
        "gates": [{"target": "greenreach", "position": [216, 738], "arrival": [668, 752], "label": "Наверх, к колодцу"}],
        "secrets": {},
        "terrain": {"size": SIZE, "style": "crypt", "art_style": "cistern", "rooms": rooms, "trails": [], "ponds": [],
                    "trees": [], "props": props, "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["flooded_cistern"] = region
    # The way down: a grate by the village well.
    gates = regions["greenreach"]["gates"]
    gates[:] = [g for g in gates if g.get("target") != "flooded_cistern"]
    gates.append({"target": "flooded_cistern", "position": [668, 722], "arrival": [216, 700], "label": "Спуск в цистерну"})
    path.write_text(jsonfmt.dumps(regions))
    print("flooded_cistern:", len(rooms), "rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
