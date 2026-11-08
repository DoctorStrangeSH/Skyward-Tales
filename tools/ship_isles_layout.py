"""The two islands reachable only by the sky ship «Ветрокрыл» (Этап 16):

    storm_isle  — «Грозовой остров»: lightning storms, needs the storm engine
                  and a thunderstorm in the sky forecast;
    mirage_isle — «Остров-мираж»: shows only in fog and only on the radar.

Both are hidden from the world map and have no gates: the ship's dock is
the only way on and off. Their weather effects, boss and hidden cache are
run by scripts/sky_ship.gd.

    python3 tools/ship_isles_layout.py && python3 tools/art/hd/build_hd.py storm_isle mirage_isle
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

STORM = {
    "name": "Грозовой остров",
    "map_color": [0.42, 0.46, 0.62],
    "level": 12,
    "enemy_power": 1.25,
    "hidden": True,
    "dock": [230, 680],
    "npcs": [],
    "chests": [
        {"id": "storm_ridge", "position": [1110, 250], "gold": 260, "item": "wind_essence", "amount": 3, "tier": "iron"},
        {"id": "storm_hollow", "position": [300, 230], "gold": 220, "item": "mana_potion", "amount": 3},
    ],
    "herbs": [],
    "story_objects": [],
    "enemies": [
        {"kind": "wisp", "position": [420, 560]},
        {"kind": "wisp", "position": [760, 640]},
        {"kind": "wisp", "position": [980, 420]},
        {"kind": "sentinel", "position": [520, 380]},
        {"kind": "sentinel", "position": [840, 330], "elite": "swift"},
        {"kind": "sentinel", "position": [1050, 620]},
        {"kind": "shade", "position": [330, 400]},
        {"kind": "shade", "position": [700, 470]},
    ],
    "gates": [],
    "secrets": {},
    "lore": [{"id": "lore_storm_isle", "position": [470, 690]}],
    "terrain": {
        "size": [1280, 864],
        "style": "spires",
        "edge_margin": 64,
        "trails": [
            [[210, 690], [360, 640], [520, 560], [640, 440], [640, 240]],
            [[640, 440], [820, 420], [1000, 330], [1110, 270]],
            [[520, 560], [760, 620], [1000, 640]],
            [[640, 440], [420, 330], [300, 250]],
        ],
        "ponds": [],
        "trees": [[160, 180], [300, 120], [960, 140], [1180, 420], [150, 450], [880, 760], [1160, 740], [420, 760], [760, 300], [520, 230]],
        "props": [
            {"kind": "standing_stones", "position": [640, 180]},
            {"kind": "standing_stones", "position": [1000, 520]},
        ],
        "blockers": [
            {"center": [640, 160], "size": [80, 50]},
            {"center": [1000, 500], "size": [80, 50]},
        ],
        "bushes": [],
    },
}

MIRAGE = {
    "name": "Остров-мираж",
    "map_color": [0.72, 0.78, 0.9],
    "level": 10,
    "enemy_power": 1.15,
    "hidden": True,
    "dock": [1050, 680],
    "npcs": [{"id": "mirage_keeper", "name": "Вейра, тень Хранительницы", "position": [640, 300]}],
    "chests": [
        {"id": "mirage_garden", "position": [260, 260], "gold": 180, "item": "health_potion", "amount": 3},
        {"id": "mirage_pond", "position": [880, 230], "gold": 200, "item": "mana_potion", "amount": 3, "tier": "iron"},
        {"id": "mirage_vault", "position": [200, 640], "gold": 350, "item": "mirage_cloak", "amount": 1, "tier": "gold"},
    ],
    "herbs": [],
    "story_objects": [],
    "enemies": [
        {"kind": "shade", "position": [420, 460]},
        {"kind": "shade", "position": [760, 520]},
        {"kind": "shade", "position": [320, 600], "elite": "fierce"},
        {"kind": "wisp", "position": [560, 640]},
        {"kind": "wisp", "position": [960, 420]},
        {"kind": "wisp", "position": [220, 380]},
    ],
    "gates": [],
    "secrets": {},
    "lore": [{"id": "lore_mirage_isle", "position": [760, 330]}],
    "terrain": {
        "size": [1280, 864],
        "style": "sky",
        "edge_margin": 64,
        "trails": [
            [[1060, 690], [900, 620], [760, 520], [640, 400], [640, 300]],
            [[640, 400], [440, 420], [260, 300]],
            [[760, 520], [520, 600], [260, 640]],
            [[640, 400], [860, 300], [880, 240]],
        ],
        "ponds": [{"circle": [980, 300, 36]}, {"circle": [420, 260, 26]}],
        "trees": [[160, 180], [340, 140], [560, 160], [760, 150], [1180, 200], [150, 500], [420, 760], [700, 760], [1180, 480], [1000, 760], [520, 300], [880, 440]],
        "props": [{"kind": "sky_archive", "position": [640, 210]}],
        "blockers": [
            {"center": [640, 172], "size": [150, 70]},
            {"center": [980, 300], "size": [60, 56]},
            {"center": [420, 260], "size": [44, 40]},
        ],
        "bushes": [],
    },
}


def main() -> int:
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text(encoding="utf-8"))
    regions["storm_isle"] = STORM
    regions["mirage_isle"] = MIRAGE
    # Docks for the ship on the islands it can reach.
    # (The ship hangs up and to the left of its ladder: trees under the hull go.)
    docks = {"salt_coast": [330, 760], "haven": [510, 1020], "sky_island": [410, 720],
             "wind_spires": [370, 700], "sky_rift": [230, 700], "sky_heart": [590, 700]}
    for region_id, (x, y) in docks.items():
        regions[region_id]["dock"] = [x, y]
        if region_id == "salt_coast":
            continue  # the wreck lies on open sand
        terrain = regions[region_id]["terrain"]
        terrain["trees"] = [t for t in terrain["trees"] if not (x - 170 < t[0] < x + 80 and y - 190 < t[1] < y + 40)]
    path.write_text(jsonfmt.dumps(regions) + "\n", encoding="utf-8")
    print("ship islands written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
