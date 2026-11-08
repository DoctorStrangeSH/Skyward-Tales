"""Этап 17: «Вольная пристань» — the hidden port of the Free Captains, a
small peaceful sky island reachable only by the ship (once the Captains are
friends, or while following Mira's logbook). Also places the faction envoys
and the three fate crystals in existing regions.

    python3 tools/free_port_layout.py && python3 tools/art/hd/build_hd.py free_port
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import jsonfmt  # noqa: E402
import haven_layout as hl  # noqa: E402

BUILDINGS = [
    ("village_tavern_2", 640, 300),
    ("village_house_slate", 380, 340),
    ("village_house_blue", 900, 340),
    ("village_house_small", 250, 560),
]
SMALL = [
    ("village_market_red", 500, 520),
    ("village_market_green", 780, 520),
    ("decor_stall_orange", 640, 620),
    ("village_well", 640, 450),
    ("village_lamp", 560, 420), ("village_lamp", 720, 420),
    ("village_lamp", 900, 640), ("village_lamp", 420, 640),
    ("village_board", 760, 380),
    ("decor_wagon", 1000, 520),
    ("village_hay", 300, 680),
    ("village_sign", 960, 700),
]

FREE_PORT = {
    "name": "Вольная пристань",
    "map_color": [0.62, 0.55, 0.42],
    "level": 8,
    "enemy_power": 1.0,
    "hidden": True,
    "peaceful": True,
    "dock": [1060, 720],
    "npcs": [
        {"id": "port_quartermaster", "name": "Бруно, квартирмейстер", "look": "tavern_keeper", "position": [640, 350]},
        {"id": "port_captain_vorn", "name": "Старый капитан Ворн", "look": "caravaner", "position": [470, 600]},
        {"id": "port_lookout", "name": "Дозорная Ника", "look": "guard", "position": [980, 760]},
    ],
    "chests": [],
    "herbs": [],
    "story_objects": [],
    "enemies": [],
    "gates": [],
    "secrets": {},
    "lore": [{"id": "lore_free_port", "position": [820, 640]}],
    "terrain": {
        "size": [1280, 864],
        "style": "sky",
        "edge_margin": 64,
        "trails": [
            [[1060, 720], [900, 680], [760, 600], [640, 500], [640, 330]],
            [[640, 500], [420, 460], [300, 600]],
            [[640, 500], [860, 440], [1000, 540]],
        ],
        "ponds": [],
        "trees": [[160, 180], [300, 140], [960, 150], [1160, 300], [150, 420], [1180, 520], [560, 780], [760, 780], [180, 760]],
        "props": [],
        "blockers": [],
        "bushes": [],
    },
}

# Faction envoys and fate crystals in existing lands.
ENVOYS = {
    "sky_island": {"id": "order_novice", "name": "Лиара, послушница ордена", "look": "herald", "position": [504, 524]},
    "salt_coast": {"id": "captain_raina", "name": "Рейна Штормовая", "look": "mercenary", "position": [510, 800]},
    "moonlit_grove": {"id": "root_keeper", "name": "Корина из Круга корней", "look": "herbalist", "position": [720, 500]},
}
CRYSTALS = {"sky_island": [500, 730], "wind_spires": [704, 604], "sky_rift": [644, 604]}


def main() -> int:
    art = hl.manifest()
    hl.BUILDINGS, hl.SMALL = BUILDINGS, SMALL
    region = json.loads(json.dumps(FREE_PORT))
    region["terrain"]["props"] = [{"kind": k, "position": [x, y]} for k, x, y in BUILDINGS + SMALL]
    region["terrain"]["blockers"] = hl.footprint_blockers(art)
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text(encoding="utf-8"))
    regions["free_port"] = region
    for region_id, npc in ENVOYS.items():
        npcs = [n for n in regions[region_id]["npcs"] if n["id"] != npc["id"]]
        npcs.append(npc)
        regions[region_id]["npcs"] = npcs
    for region_id, spot in CRYSTALS.items():
        regions[region_id]["fate_crystal"] = spot
    path.write_text(jsonfmt.dumps(regions) + "\n", encoding="utf-8")
    print("free port written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
