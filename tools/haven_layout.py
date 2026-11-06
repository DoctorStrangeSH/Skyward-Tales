"""Builds the "haven" region (Тихая Гавань) in data/regions.json: a peaceful
island town with a fountain plaza, houses, a market, a windmill, fields, a
pond and the Keepers' sky anchor. No enemies.

    python3 tools/haven_layout.py      # then: python3 tools/art/build.py --only world

Collision blockers come from each building's footprint (art_manifest sizes);
trees and bushes are scattered away from roads, buildings and objects.
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import jsonfmt  # noqa: E402
from region_scatter import blocked  # noqa: E402

W, H = 1600, 1088
PLAZA = (800, 560)

# (kind, x, y) — y is the bottom of the art (where it stands).
BUILDINGS = [
    ("village_hall", 630, 450),
    ("village_house_moss", 975, 450),
    ("village_tavern_2", 1040, 760),
    ("village_library_2", 570, 770),
    ("village_house_long", 1200, 515),
    ("village_house_wine", 450, 520),
    ("village_house_small", 335, 520),
    ("village_windmill", 175, 520),
    ("village_house_blue", 470, 330),
    ("village_house_slate", 320, 290),
    ("village_home_2", 1150, 330),
    ("village_house_large", 1330, 350),
    ("village_anchor", 800, 1010),
]
SMALL = [
    ("village_fountain", 800, 585),
    ("village_market_red", 1140, 650), ("village_market_green", 1250, 650), ("decor_stall_white", 1350, 650),
    ("village_bench", 712, 640), ("village_bench", 888, 640), ("village_bench", 760, 960), ("village_bench", 1240, 980),
    ("village_flowers_a", 700, 505), ("village_flowers_b", 900, 505), ("village_flowers_c", 700, 680),
    ("village_flowers_a", 900, 680), ("village_flowers_b", 760, 210), ("village_flowers_c", 840, 210),
    ("village_flowers_a", 450, 545), ("village_flowers_c", 1200, 540), ("village_flowers_b", 975, 475),
    ("village_flowers_a", 1330, 375), ("village_flowers_c", 300, 940), ("village_flowers_b", 640, 950),
    ("village_arch", 800, 190),
    ("village_well", 1110, 860),
    ("village_field", 130, 680), ("village_field", 210, 680), ("village_field", 290, 680),
    ("village_hay", 360, 660), ("village_hay", 70, 610),
    ("village_lamp", 680, 545), ("village_lamp", 920, 545), ("village_lamp", 680, 625), ("village_lamp", 920, 625),
    ("village_lamp", 772, 340), ("village_lamp", 828, 120), ("village_lamp", 560, 575), ("village_lamp", 1040, 575),
    ("village_lamp", 772, 820), ("village_lamp", 1320, 575), ("village_lamp", 290, 575),
    ("village_sign", 850, 300), ("village_board", 700, 455),
    ("decor_wagon", 1440, 600), ("decor_potted_plant", 1000, 780), ("decor_potted_plant", 1080, 780),
    ("village_fence_h", 105, 720), ("village_fence_h", 139, 720), ("village_fence_h", 173, 720),
    ("village_fence_h", 207, 720), ("village_fence_h", 241, 720), ("village_fence_h", 275, 720), ("village_fence_h", 309, 720),
]
TRAILS = [
    [[800, 0], [800, 200], [800, 470]],
    [[710, 575], [560, 580], [420, 565], [300, 580], [180, 560]],
    [[890, 575], [1050, 585], [1200, 575], [1350, 575], [1600, 560]],
    [[800, 660], [800, 800], [800, 930]],
    [[800, 800], [960, 830], [1120, 880], [1260, 930]],
    [[560, 580], [540, 420], [440, 360], [320, 320]],
    [[1050, 585], [1080, 420], [1150, 360], [1330, 370]],
]
PLAZAS = [{"circle": [800, 572, 96]}, {"circle": [800, 1000, 62]}, {"rect": [1090, 604, 320, 60]}]
PONDS = [{"circle": [1380, 930, 92]}]

NPCS = [
    {"id": "haven_warden", "name": "Агата, смотрительница Гавани", "position": [630, 478]},
    {"id": "haven_baker", "name": "Пекарь Тимофей", "position": [1200, 545]},
    {"id": "haven_gardener", "name": "Садовница Ива", "position": [250, 610],
     "wander": [[250, 610], [330, 610], [200, 750], [120, 600]]},
    {"id": "haven_child", "name": "Тиша", "position": [740, 700],
     "wander": [[740, 700], [860, 700], [880, 520], [720, 520], [620, 640]]},
    {"id": "haven_bard", "name": "Бард Лель", "position": [1040, 790]},
    {"id": "haven_anchor", "name": "Сол, хранитель якоря", "position": [870, 1020]},
    {"id": "haven_fisher", "name": "Рыбак Ольгерд", "look": "settler_fisher", "position": [1265, 905]},
    {"id": "haven_storyteller", "name": "Сказительница Веста", "look": "librarian", "position": [570, 800]},
    {"id": "haven_villager_a", "name": "Прачка Дана", "position": [1180, 690],
     "wander": [[1180, 690], [960, 600], [860, 700], [1110, 890], [1300, 690]]},
    {"id": "haven_villager_b", "name": "Плотник Яр", "position": [420, 600],
     "wander": [[420, 600], [560, 600], [540, 420], [330, 340], [300, 600]]},
]
HERBS = [
    *[{"id": "lost_letter", "name": "Потерянное письмо", "quest": "haven_letters", "position": p}
      for p in ([300, 395], [1430, 470], [985, 975], [95, 820])],
    *[{"id": "flour_sack", "name": "Мешок муки", "quest": "haven_flour", "position": p}
      for p in ([110, 560], [1500, 700], [690, 300])],
    *[{"id": "sky_seed", "name": "Небесное семечко", "quest": "haven_seeds", "position": p}
      for p in ([1460, 230], [1060, 240], [420, 880], [1520, 1010], [200, 980])],
    *[{"id": "song_scroll", "name": "Листок со старой песней", "quest": "haven_songs", "position": p}
      for p in ([630, 240], [1290, 780], [1480, 560])],
    {"id": "lost_kitten", "name": "Котёнок Пушок", "quest": "haven_kitten", "position": [1540, 870]},
]
LORE = [
    {"id": "haven_founding", "position": [860, 120]},
    {"id": "haven_anchor_stone", "position": [720, 1020]},
    {"id": "haven_fallen_isles", "position": [1500, 140]},
    {"id": "haven_windmill", "position": [100, 470]},
    {"id": "haven_pond", "position": [1490, 840]},
]
GATHER = [
    {"kind": "fish", "position": [1290, 860]}, {"kind": "fish", "position": [1380, 830]}, {"kind": "fish", "position": [1470, 930]},
    {"kind": "healroot", "position": [1000, 300]}, {"kind": "bluebell", "position": [620, 920]},
    {"kind": "bluebell", "position": [1500, 300]}, {"kind": "wood", "position": [1520, 420]},
    {"kind": "stone", "position": [140, 300]}, {"kind": "healroot", "position": [380, 960]},
]


def manifest() -> dict:
    return json.loads((ROOT / "assets" / "art_manifest.json").read_text())


def size_of(art: dict, kind: str) -> tuple[int, int]:
    entry = art.get(f"world/{kind}.png", {})
    w, h = entry.get("size", [24, 24])
    return int(w), int(h)


def footprint_blockers(art: dict) -> list:
    result = []
    for kind, x, y in BUILDINGS:
        w, h = size_of(art, kind)
        if kind == "village_windmill":
            result.append({"center": [x, y - 10], "size": [40, 20]})
        elif kind == "village_anchor":
            result.append({"center": [x, y - 8], "size": [42, 16]})
        else:
            result.append({"center": [x, y - 13], "size": [int(w * 0.8), 26]})
    for kind, x, y in SMALL:
        w, h = size_of(art, kind)
        if kind == "village_fountain":
            result.append({"center": [x, y - 12], "size": [52, 18]})
        elif kind.startswith("village_market") or kind.startswith("decor_stall"):
            result.append({"center": [x, y - 6], "size": [w - 8, 10]})
        elif kind == "village_arch":
            result.append({"center": [x - 20, y - 3], "size": [5, 6]})
            result.append({"center": [x + 20, y - 3], "size": [5, 6]})
        elif kind in ("village_lamp", "village_sign"):
            result.append({"center": [x, y - 2], "size": [4, 4]})
        elif kind.startswith("village_fence_h"):
            result.append({"center": [x, y - 4], "size": [34, 6]})
        elif kind.startswith("village_flowers") or kind == "village_bench":
            result.append({"center": [x, y - 4], "size": [w - 6, 6]})
        elif kind == "village_field":
            result.append({"center": [x, y - 15], "size": [64, 30]})
        elif kind == "village_well":
            result.append({"center": [x, y - 6], "size": [26, 12]})
        else:
            result.append({"center": [x, y - 4], "size": [max(8, w - 12), 8]})
    return result


def art_rects(art: dict) -> list:
    rects = []
    for kind, x, y in BUILDINGS + SMALL:
        w, h = size_of(art, kind)
        rects.append((x - w / 2 - 12, y - h - 8, x + w / 2 + 12, y + 18))
    return rects


def scatter(region: dict, art: dict, seed: int = 11) -> None:
    rng = random.Random(seed)
    rects = art_rects(art)
    placed: list = []

    def free(p, margin) -> bool:
        x, y = p
        if any(x0 - margin < x < x1 + margin and y0 - margin < y < y1 + margin for x0, y0, x1, y1 in rects):
            return False
        if math.hypot(x - PLAZA[0], y - PLAZA[1]) < 175 or math.hypot(x - 800, y - 1000) < 110:
            return False
        for lore in region.get("lore", []):
            if math.hypot(x - lore["position"][0], y - lore["position"][1]) < 40:
                return False
        return not blocked(region, p, margin)

    def pick(count: int, spacing: float, margin: float, edge_bias: bool) -> list:
        result = []
        tries = 0
        while len(result) < count and tries < count * 120:
            tries += 1
            if edge_bias and rng.random() < 0.6:
                side = rng.randrange(4)
                p = [rng.randint(20, W - 20), rng.randint(30, H - 20)]
                band = rng.randint(20, 150)
                if side == 0:
                    p[0] = band
                elif side == 1:
                    p[0] = W - band
                elif side == 2:
                    p[1] = band + 10
                else:
                    p[1] = H - band
            else:
                p = [rng.randint(20, W - 20), rng.randint(30, H - 20)]
            if not free(p, margin):
                continue
            if any(math.hypot(p[0] - q[0], p[1] - q[1]) < spacing for q in placed):
                continue
            placed.append(p)
            result.append(p)
        return result

    region["terrain"]["trees"] = pick(95, 40, 6, True)
    region["terrain"]["bushes"] = pick(70, 24, 0, False)


def build() -> dict:
    art = manifest()
    region = {
        "name": "Тихая Гавань",
        "map_color": [0.95, 0.72, 0.8],
        "level": 1,
        "enemy_power": 1.0,
        "peaceful": True,
        "waystone": [860, 380],
        "map_pos": [0.1, 0.84],
        "npcs": NPCS,
        "chests": [{"id": "haven_attic", "position": [1545, 160], "gold": 60, "item": "berry_pie", "amount": 2}],
        "herbs": HERBS,
        "enemies": [],
        "gates": [{"target": "greenreach", "position": [800, 36], "arrival": [200, 1180], "label": "Мост в Зелёные Пределы"}],
        "secrets": {},
        "gather": GATHER,
        "lore": LORE,
        "story_objects": [],
        "terrain": {
            "size": [W, H],
            "style": "haven",
            "trails": TRAILS,
            "ponds": PONDS,
            "plazas": PLAZAS,
            "props": [{"kind": k, "position": [x, y]} for k, x, y in BUILDINGS + SMALL],
            "blockers": footprint_blockers(art),
            "trees": [],
            "bushes": [],
        },
    }
    scatter(region, art)
    return region


def main() -> int:
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    regions["haven"] = build()
    # The south road of the Green Reaches ends at the bridge to the Haven.
    green = regions["greenreach"]
    green["gates"] = [g for g in green["gates"] if g.get("target") != "haven"]
    green["gates"].append({"target": "haven", "position": [200, 1244], "arrival": [800, 110],
                           "label": "Мост в Тихую Гавань"})
    path.write_text(jsonfmt.dumps(regions))
    t = regions["haven"]["terrain"]
    print(f"haven: {len(t['props'])} props, {len(t['blockers'])} blockers, {len(t['trees'])} trees, {len(t['bushes'])} bushes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
