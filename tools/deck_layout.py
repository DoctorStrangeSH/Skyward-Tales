"""The deck of the «Ветрокрыл» (region "ship_deck", этап 24): where boarders
are fought in an air battle (scripts/sky_battle.gd puts barrels, crates and
the mast on it and sends the ship on when the deck is clear).

    python3 tools/deck_layout.py && python3 tools/art/hd/build_hd.py ship_deck
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [800, 480]
DECK = [144, 128, 512, 224]


def main() -> int:
    region = {
        "name": "Палуба корабля",
        "map_color": [0.62, 0.45, 0.26],
        "level": 8,
        "enemy_power": 1.0,
        "hidden": True,
        "npcs": [], "chests": [], "herbs": [], "story_objects": [], "enemies": [],
        "gates": [],
        "secrets": {},
        "terrain": {"size": SIZE, "style": "crypt", "art_style": "lodge", "rooms": [DECK], "trails": [], "ponds": [],
                    "trees": [], "props": [], "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["ship_deck"] = region
    path.write_text(jsonfmt.dumps(regions))
    print("ship_deck written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
