"""Stage 21: trees in groves instead of an even scatter.

    python3 tools/world_groves.py [region ...] && python3 tools/art/hd/build_hd.py <regions>

The old layouts spread trees evenly (one every ~40 px), which reads as a
grid. This tool keeps each region's forest where it was (the zone within
reach of the old trees) but replants it: clumps of 3–7 trees of different
density with little clearings between them, and a few loners at the edge.
Trees keep clear of trails, water, walls, houses, people, chests, herbs,
foes and gates; trunks stay ≥ 30 px apart (tests/world_layout.gd).
Deterministic per region. Default regions: every open-air land.
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402
import world_tidy as wt  # noqa: E402

OPEN_AIR = ("day", "haven", "coast", "marsh", "mountain", "night", "ash", "sky", "spires")
GAP = 31.0


def objects(region: dict) -> list:
    out = []
    for key in wt.OBJECT_KEYS + ("gates", "contract_boards"):
        for o in region.get(key, []) or []:
            if isinstance(o, dict) and "position" in o:
                out.append(tuple(o["position"]))
    for spot in ("waystone", "dock", "fate_crystal", "spawn"):
        if isinstance(region.get(spot), list):
            out.append(tuple(region[spot]))
    for prop in region["terrain"].get("props", []):
        out.append(tuple(prop["position"]))
    return out


def replant(region_id: str, region: dict) -> tuple[int, int]:
    terrain = region["terrain"]
    old = [tuple(t) for t in terrain.get("trees", [])]
    if len(old) < 12:
        return len(old), len(old)
    rng = random.Random(sum(ord(c) for c in region_id) * 977)
    things = objects(region)
    w, h = terrain["size"]
    margin = float(terrain.get("edge_margin", 0)) + 22

    def in_forest(p) -> bool:
        return any(abs(p[0] - x) < 50 and abs(p[1] - y) < 50 for x, y in old)

    def free(p, trees) -> bool:
        x, y = p
        if not (margin < x < w - margin and margin + 14 < y < h - margin - 12):
            return False
        foot = (x, y + 8)
        if wt.trail_distance(terrain, foot) < 30 or wt.in_water(terrain, foot, 16) or wt.in_wall(terrain, foot, 10):
            return False
        if any(math.hypot(x - ox, y + 8 - oy) < 34 for ox, oy in things):
            return False
        return all(math.hypot(x - tx, y - ty) >= GAP for tx, ty in trees)

    trees: list = []
    # Clump centres: spread over the old forest.
    centres: list = []
    tries = 0
    while tries < 6000:
        tries += 1
        c = (rng.uniform(margin, w - margin), rng.uniform(margin, h - margin))
        if not in_forest(c) or any(math.hypot(c[0] - a, c[1] - b) < 96 for a, b in centres):
            continue
        centres.append(c)
    for cx, cy in centres:
        if len(trees) >= int(len(old) * 0.86):
            break
        dense = rng.random() < 0.45
        count = rng.randint(4, 7) if dense else rng.randint(2, 4)
        spread = 46.0 if dense else 58.0
        placed = 0
        for _ in range(60):
            if placed >= count:
                break
            ang, r = rng.uniform(0, math.tau), spread * math.sqrt(rng.random())
            p = (round(cx + math.cos(ang) * r), round(cy + math.sin(ang) * r * 0.8))
            if in_forest(p) and free(p, trees):
                trees.append(p)
                placed += 1
    # Loners fill what is left, up to the old count.
    for _ in range(4000):
        if len(trees) >= len(old):
            break
        p = (round(rng.uniform(margin, w - margin)), round(rng.uniform(margin, h - margin)))
        if in_forest(p) and free(p, trees) and all(math.hypot(p[0] - tx, p[1] - ty) >= 44 for tx, ty in trees):
            trees.append(p)
    trees.sort(key=lambda t: (t[1], t[0]))
    terrain["trees"] = [list(t) for t in trees]
    # Bushes gather at the feet of the clumps and along the forest edge.
    bushes = []
    for x, y in terrain.get("bushes", []):
        if all(math.hypot(x - tx, y - (ty + 10)) > 14 for tx, ty in trees):
            bushes.append([x, y])
    terrain["bushes"] = bushes
    return len(old), len(trees)


def main(argv: list[str]) -> int:
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text(encoding="utf-8"))
    wanted = argv or [rid for rid, r in regions.items() if r.get("terrain", {}).get("style") in OPEN_AIR]
    for region_id in wanted:
        before, after = replant(region_id, regions[region_id])
        log: list = []
        wt.place_objects(regions[region_id], log)
        print(f"  {region_id}: {before} → {after} trees" + (f", moved {len(log)} objects" if log else ""))
    path.write_text(jsonfmt.dumps(regions) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
