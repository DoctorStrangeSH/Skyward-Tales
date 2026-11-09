"""Package F of the owner's list (№39, 9 ноября 2026): tidy the world layout.

    python3 tools/world_tidy.py [--check] && python3 tools/art/hd/build_hd.py <changed regions>

For every region in data/regions.json:
  • ponds (water, bog, lava) that a trail runs through are moved off the
    trail, with the fishing spots that belong to them;
  • every house gets a short straight footpath from its door to the nearest
    trail (when the trail is close and the way is clear);
  • trees and bushes standing on paths, in water, in houses or in each other
    are removed;
  • NPCs, chests, herbs, gathering spots, rune stones and foes standing in
    water, in walls or in a tree trunk are moved to the nearest free spot;
    fishing spots go to the shore of their water.
Run it after the per-region layout tools (haven_layout.py, ...) — they
rewrite the terrain. `--check` only reports. The game's own guard is
tests/world_layout.gd.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

HOUSES = ("village_house", "village_hall", "village_home", "village_library", "village_tavern", "village_windmill", "mine_entrance")
OBJECT_KEYS = ("npcs", "chests", "herbs", "gather", "lore", "story_objects", "supply_crates", "map_fragments", "resource_nodes", "enemies")
TREE_GAP = 30.0
PATH_MAX = 260.0


def seg_distance(p, a, b) -> float:
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def closest_on_segment(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / length))
    return (ax + t * dx, ay + t * dy)


def trail_distance(terrain: dict, p) -> float:
    best = 1e9
    for trail in terrain.get("trails", []):
        for a, b in zip(trail, trail[1:]):
            best = min(best, seg_distance(p, a, b))
    return best


def pond_depth(pond: dict, p) -> float:
    """>0 inside the water (px from the shore), <0 outside."""
    x, y = p
    if "circle" in pond:
        cx, cy, r = pond["circle"]
        return r - math.hypot(x - cx, (y - cy) * 1.08)
    rx, ry, rw, rh = pond["rect"]
    return min(x - rx, rx + rw - x, y - ry, ry + rh - y)


def in_water(terrain: dict, p, pad: float = 0.0) -> bool:
    return any(pond_depth(pond, p) > -pad for pond in terrain.get("ponds", []))


def in_wall(terrain: dict, p, pad: float = 0.0) -> bool:
    for blocker in terrain.get("blockers", []):
        (cx, cy), (w, h) = blocker["center"], blocker["size"]
        if abs(p[0] - cx) < w / 2 + pad and abs(p[1] - cy) < h / 2 + pad:
            return True
    return False


def in_tree(terrain: dict, p, pad: float = 0.0) -> bool:
    # The trunk collider: 10×11 at (x, y+5).
    return any(abs(p[0] - x) < 5 + pad and abs(p[1] - (y + 5)) < 5.5 + pad for x, y in terrain.get("trees", []))


def inside_map(region: dict, p) -> bool:
    terrain = region["terrain"]
    w, h = terrain["size"]
    m = float(terrain.get("edge_margin", 0)) + 20
    return m < p[0] < w - m and m < p[1] < h - m


def free_spot(region: dict, p, pad: float = 8.0, avoid_trails: bool = False):
    """The nearest spot that is dry, outside walls and trunks."""
    terrain = region["terrain"]
    for radius in range(0, 200, 6):
        steps = max(1, int(2 * math.pi * radius / 6))
        for k in range(steps):
            angle = 2 * math.pi * k / steps
            q = (round(p[0] + radius * math.cos(angle)), round(p[1] + radius * math.sin(angle)))
            if not inside_map(region, q):
                continue
            if in_water(terrain, q, pad) or in_wall(terrain, q, pad) or in_tree(terrain, q, pad):
                continue
            if avoid_trails and trail_distance(terrain, q) < 18:
                continue
            return list(q)
    return list(p)


def shore_spot(terrain: dict, p):
    """A fishing spot on the shore of the nearest water, facing it."""
    best = None
    for pond in terrain.get("ponds", []):
        if best is None or abs(pond_depth(pond, p)) < abs(pond_depth(best, p)):
            best = pond
    if best is None:
        return list(p)
    if "circle" in best:
        cx, cy, r = best["circle"]
        dx, dy = p[0] - cx, p[1] - cy
        d = math.hypot(dx, dy) or 1.0
        return [round(cx + dx / d * (r + 14)), round(cy + dy / d * (r + 14))]
    rx, ry, rw, rh = best["rect"]
    # Step out through the nearest side.
    sides = [(p[0] - rx, (rx - 14, p[1])), (rx + rw - p[0], (rx + rw + 14, p[1])), (p[1] - ry, (p[0], ry - 14)), (ry + rh - p[1], (p[0], ry + rh + 14))]
    return [round(v) for v in min(sides)[1]]


def move_ponds_off_trails(region: dict, log: list) -> None:
    terrain = region["terrain"]
    for pond in terrain.get("ponds", []):
        if "circle" not in pond:
            continue
        cx, cy, r = pond["circle"]
        if trail_distance(terrain, (cx, cy)) >= r + 16:
            continue
        # Push the pool away from the nearest trail point.
        nearest = None
        for trail in terrain.get("trails", []):
            for a, b in zip(trail, trail[1:]):
                q = closest_on_segment((cx, cy), a, b)
                if nearest is None or math.hypot(q[0] - cx, q[1] - cy) < math.hypot(nearest[0] - cx, nearest[1] - cy):
                    nearest = q
        dx, dy = cx - nearest[0], cy - nearest[1]
        d = math.hypot(dx, dy) or 1.0
        ux, uy = dx / d, dy / d
        moved = (cx, cy)
        for step in range(4, 260, 4):
            q = (cx + ux * step, cy + uy * step)
            if trail_distance(terrain, q) >= r + 18 and inside_map(region, (q[0] - r, q[1] - r)) and inside_map(region, (q[0] + r, q[1] + r)):
                moved = q
                break
        shift = (round(moved[0] - cx), round(moved[1] - cy))
        if shift == (0, 0):
            continue
        pond["circle"] = [cx + shift[0], cy + shift[1], r]
        # Its fishing spots and the foes in it move along.
        for key in ("gather", "enemies"):
            for item in region.get(key, []) or []:
                px, py = item["position"]
                if math.hypot(px - cx, py - cy) <= r + 30:
                    item["position"] = [px + shift[0], py + shift[1]]
        log.append(f"pond {cx},{cy} moved by {shift}")


def add_footpaths(region: dict, log: list) -> None:
    terrain = region["terrain"]
    trails = terrain.setdefault("trails", [])
    if not trails:
        return
    existing = [t for t in trails if not (isinstance(t, list) and len(t) == 2 and getattr(t, "_footpath", False))]
    for prop in terrain.get("props", []):
        kind = str(prop.get("kind", ""))
        if not kind.startswith(HOUSES):
            continue
        x, y = prop["position"]
        door = (x, y + 8)
        if trail_distance(terrain, door) <= 34:
            continue
        nearest = None
        for trail in existing:
            for a, b in zip(trail, trail[1:]):
                q = closest_on_segment(door, a, b)
                if nearest is None or math.dist(q, door) < math.dist(nearest, door):
                    nearest = q
        if nearest is None or math.dist(nearest, door) > PATH_MAX:
            continue
        # Straight down from the door first, then to the trail: neat paths.
        corner = (door[0], nearest[1]) if abs(nearest[1] - door[1]) > 24 and abs(nearest[0] - door[0]) > 24 else None
        points = [door] + ([corner] if corner else []) + [nearest]
        clear = True
        for a, b in zip(points, points[1:]):
            for k in range(1, 20):
                q = (a[0] + (b[0] - a[0]) * k / 20, a[1] + (b[1] - a[1]) * k / 20)
                if in_wall(terrain, q, 4) or in_water(terrain, q, 6):
                    clear = False
        if not clear:
            continue
        trails.append([[round(px), round(py)] for px, py in points])
        log.append(f"footpath for {kind} at {x},{y}")


def prune_scenery(region: dict, log: list) -> None:
    terrain = region["terrain"]
    keep = []
    removed = 0
    objects = [o["position"] for key in OBJECT_KEYS + ("gates",) for o in region.get(key, []) or [] if isinstance(o, dict) and "position" in o]
    for spot in ("waystone", "dock", "fate_crystal"):
        if region.get(spot):
            objects.append(region[spot])
    for x, y in terrain.get("trees", []):
        p = (x, y + 8)
        if (trail_distance(terrain, p) < 20 or in_water(terrain, p, 12) or in_wall(terrain, p, 6)
                or any(math.hypot(x - kx, y - ky) < TREE_GAP for kx, ky in keep)
                or any(math.hypot(x - ox, y + 8 - oy) < 22 for ox, oy in objects)):
            removed += 1
            continue
        keep.append([x, y])
    terrain["trees"] = keep
    bushes = []
    for x, y in terrain.get("bushes", []):
        if trail_distance(terrain, (x, y)) < 14 or in_water(terrain, (x, y), 6) or in_wall(terrain, (x, y), 2):
            removed += 1
            continue
        bushes.append([x, y])
    terrain["bushes"] = bushes
    if removed:
        log.append(f"{removed} trees/bushes removed")


def place_objects(region: dict, log: list) -> None:
    terrain = region["terrain"]
    for key in OBJECT_KEYS:
        for item in region.get(key, []) or []:
            if not isinstance(item, dict) or "position" not in item:
                continue
            p = tuple(item["position"])
            if key == "gather" and item.get("kind") == "fish":
                if in_water(terrain, p, 6) or in_wall(terrain, p, 2):
                    item["position"] = shore_spot(terrain, p)
                    log.append(f"fishing spot {p} → shore {item['position']}")
                continue
            if in_water(terrain, p, 6) or in_wall(terrain, p, 4) or in_tree(terrain, p, 4):
                item["position"] = free_spot(region, p, 8, key in ("chests", "herbs"))
                log.append(f"{key} {item.get('id', item.get('kind', ''))} {list(p)} → {item['position']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = ROOT / "data" / "regions.json"
    regions = json.loads(path.read_text(encoding="utf-8"))
    changed = []
    for region_id, region in regions.items():
        if "terrain" not in region:
            continue
        before = json.dumps(region, sort_keys=True)
        log: list = []
        move_ponds_off_trails(region, log)
        add_footpaths(region, log)
        place_objects(region, log)
        prune_scenery(region, log)
        if json.dumps(region, sort_keys=True) != before:
            changed.append(region_id)
            print(region_id)
            for line in log:
                print("   ", line)
    if changed and not args.check:
        path.write_text(jsonfmt.dumps(regions) + "\n", encoding="utf-8")
    print("changed:", " ".join(changed) if changed else "nothing")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
