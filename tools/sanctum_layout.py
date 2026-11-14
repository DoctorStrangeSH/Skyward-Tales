"""The Keepers' Abode (region "keepers_sanctum", этап 24): a story dungeon
under the Sky Island. Halls go up one above another, joined by corridors;
three seals bar the way (scripts/keepers_sanctum.gd opens them):
    start → runes (6 rune stones, lights puzzle) ─seal→ crystals (singing
    crystals in an order told by a riddle) ─seal→ guard hall (the Abode's
    stone guards) ─seal→ the Abode: the hidden home of the last Keepers.

    python3 tools/sanctum_layout.py && python3 tools/art/hd/build_hd.py keepers_sanctum
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

SIZE = [800, 1456]
X, W = 240, 320
ABODE = [160, 64, 480, 240]
GUARD = [X, 376, W, 208]
CRYSTALS = [X, 656, W, 208]
RUNES = [X, 936, W, 208]
START = [X, 1216, W, 176]
HALLS = [ABODE, GUARD, CRYSTALS, RUNES, START]


def main() -> int:
    rooms = list(HALLS)
    for upper, lower in zip(HALLS, HALLS[1:]):
        top = upper[1] + upper[3] - 4
        rooms.append([368, top, 64, lower[1] - top + 4])
    props = []
    for x, y, w, _h in HALLS:
        props += [{"kind": "crypt_torch", "position": [x + 36, y + 12]}, {"kind": "crypt_torch", "position": [x + w - 36, y + 12]}]
    enemies = [
        {"kind": "sentinel", "position": [300, 470]}, {"kind": "sentinel", "position": [500, 470]},
        {"kind": "golem", "position": [400, 430]}, {"kind": "wisp", "position": [330, 540]}, {"kind": "wisp", "position": [470, 540]},
    ]
    region = {
        "name": "Обитель Хранителей",
        "map_color": [0.55, 0.5, 0.75],
        "level": 11,
        "enemy_power": 1.1,
        "hidden": True,
        "npcs": [
            {"id": "keeper_olva", "name": "Ольва, хранительница летописи", "position": [330, 150], "look": "librarian"},
            {"id": "keeper_saim", "name": "Брат Сайм, страж огня", "position": [470, 150], "look": "keeper"},
        ],
        "chests": [], "herbs": [], "story_objects": [], "enemies": enemies,
        "gates": [{"target": "sky_island", "position": [400, 1360], "arrival": [880, 640], "label": "Наверх, на Небесный остров"}],
        "secrets": {},
        "terrain": {"size": SIZE, "style": "crypt", "rooms": rooms, "trails": [], "ponds": [],
                    "trees": [], "props": props, "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["keepers_sanctum"] = region
    gates = regions["sky_island"]["gates"]
    gates[:] = [g for g in gates if g.get("target") != "keepers_sanctum"]
    gates.append({"target": "keepers_sanctum", "position": [880, 600], "arrival": [400, 1300], "label": "Скрытая лестница Хранителей",
                  "requires_quest": "main_archive", "locked_message": "Плиты пола не поддаются. Архивариус говорил о тайном спуске — сначала помогите ему с Архивом."})
    path.write_text(jsonfmt.dumps(regions))
    print("keepers_sanctum:", len(rooms), "rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
