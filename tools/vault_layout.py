"""The Pattern Vault (region "pattern_vault"): a 3×3 grid of stone halls
joined by corridors. Its contents (foes, traps, chests, rune puzzle, the
warden) are rolled anew for every expedition by scripts/expeditions.gd;
this script only lays out the halls, torches and statues.

    python3 tools/vault_layout.py && python3 tools/art/hd/build_hd.py pattern_vault
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

RW, RH = 288, 208
COLS = [64, 480, 896]
ROWS = [64, 368, 672]
# Corridors between halls (col,row)-(col,row); the treasure hall (0,0) only
# opens from below, through the rune seal.
LINKS = [((1, 0), (2, 0)), ((0, 1), (1, 1)), ((1, 1), (2, 1)), ((0, 2), (1, 2)), ((1, 2), (2, 2)),
         ((0, 2), (0, 1)), ((0, 1), (0, 0)), ((1, 2), (1, 1)), ((1, 1), (1, 0)), ((2, 2), (2, 1))]


def hall(c: int, r: int) -> list:
    return [COLS[c], ROWS[r], RW, RH]


def centre(c: int, r: int) -> tuple[int, int]:
    return COLS[c] + RW // 2, ROWS[r] + RH // 2


def main() -> int:
    rooms = [hall(c, r) for r in range(3) for c in range(3)]
    for (c1, r1), (c2, r2) in LINKS:
        x1, y1 = centre(c1, r1)
        x2, y2 = centre(c2, r2)
        if r1 == r2:
            rooms.append([min(x1, x2) + RW // 2 - 4, y1 - 32, abs(x2 - x1) - RW + 8, 64])
        else:
            rooms.append([x1 - 32, min(y1, y2) + RH // 2 - 4, 64, abs(y2 - y1) - RH + 8])
    props, trees = [], []
    for r in range(3):
        for c in range(3):
            x, y = COLS[c], ROWS[r]
            props += [{"kind": "crypt_torch", "position": [x + 40, y + 12]}, {"kind": "crypt_torch", "position": [x + RW - 40, y + 12]}]
            trees += [[x + 26, y + 34], [x + RW - 26, y + 34]]
    region = {
        "name": "Хранилище Узора",
        "map_color": [0.36, 0.32, 0.52],
        "level": 6,
        "enemy_power": 1.0,
        "hidden": True,
        "npcs": [], "chests": [], "herbs": [], "story_objects": [], "enemies": [],
        "gates": [{"target": "greenreach", "position": [208, 868], "arrival": [480, 1150], "label": "Выход из хранилища"}],
        "secrets": {},
        "terrain": {"size": [1248, 944], "style": "crypt", "rooms": rooms, "trails": [], "ponds": [],
                    "trees": trees, "props": props, "bushes": []},
    }
    import terrain  # noqa: E402
    region["terrain"]["blockers"] = terrain.crypt_blockers(region["terrain"])
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["pattern_vault"] = region
    path.write_text(jsonfmt.dumps(regions))
    print("pattern_vault:", len(rooms), "rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
