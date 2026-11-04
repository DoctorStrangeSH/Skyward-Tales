"""Scatter trees and decor bushes over a region without touching trails,
ponds, blockers, gates or gameplay objects (NPCs, chests, enemies...).

    python3 tools/region_scatter.py <region_id> [--trees N] [--bushes N] [--seed S]

Rewrites the region's terrain "trees"/"bushes" in data/regions.json."""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402


def _segment_distance(p, a, b) -> float:
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def blocked(region: dict, p, margin: float) -> bool:
    t = region["terrain"]
    w, h = t["size"]
    x, y = p
    if x < 30 or y < 40 or x > w - 30 or y > h - 30:
        return False  # the border band is fine for trees
    for trail in t.get("trails", []):
        for a, b in zip(trail, trail[1:]):
            if _segment_distance(p, a, b) < 26 + margin:
                return True
    for pond in t.get("ponds", []):
        if "circle" in pond:
            cx, cy, r = pond["circle"]
            if math.hypot(x - cx, y - cy) < r + 18 + margin:
                return True
        else:
            rx, ry, rw, rh = pond["rect"]
            if rx - 18 - margin < x < rx + rw + 18 + margin and ry - 18 - margin < y < ry + rh + 18 + margin:
                return True
    for blocker in t.get("blockers", []):
        (cx, cy), (bw, bh) = blocker["center"], blocker["size"]
        if abs(x - cx) < bw / 2 + 14 + margin and abs(y - cy) < bh / 2 + 22 + margin:
            return True
    points = []
    for key in ("npcs", "chests", "herbs", "enemies", "gates", "gather", "supply_crates", "map_fragments", "story_objects", "resource_nodes"):
        for item in region.get(key, []) or []:
            if isinstance(item, dict) and "position" in item:
                points.append(item["position"])
    if region.get("waystone"):
        points.append(region["waystone"])
    for prop in t.get("props", []):
        points.append(prop["position"])
    return any(math.hypot(x - px, y - py) < 44 + margin for px, py in points)


def scatter(region: dict, trees: int, bushes: int, seed: int) -> None:
    rng = random.Random(seed)
    w, h = region["terrain"]["size"]
    placed: list = []

    def pick(count: int, spacing: float, margin: float) -> list:
        result = []
        tries = 0
        while len(result) < count and tries < count * 80:
            tries += 1
            p = [rng.randint(20, w - 20), rng.randint(30, h - 20)]
            if blocked(region, p, margin):
                continue
            if any(math.hypot(p[0] - q[0], p[1] - q[1]) < spacing for q in placed):
                continue
            placed.append(p)
            result.append(p)
        return result

    region["terrain"]["trees"] = pick(trees, 34, 6)
    region["terrain"]["bushes"] = pick(bushes, 26, 0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("region")
    parser.add_argument("--trees", type=int, default=140)
    parser.add_argument("--bushes", type=int, default=40)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text())
    scatter(regions[args.region], args.trees, args.bushes, args.seed)
    path.write_text(jsonfmt.dumps(regions))
    print(f"{args.region}: {len(regions[args.region]['terrain']['trees'])} trees, {len(regions[args.region]['terrain']['bushes'])} bushes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
