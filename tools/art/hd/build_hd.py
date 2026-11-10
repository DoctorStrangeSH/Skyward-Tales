"""Builds the HD world for regions whose style has an HD recipe:
sprites (tools/art/hd/sprites.py), ground, island edges and minimap.

    python3 tools/art/hd/build_hd.py [region ...]
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from hd import apron, ground, minimap, pack, sprites, title  # noqa: E402
from hd.styles import STYLE  # noqa: E402

ROOT = pack.ROOT
OUT = ROOT / "assets" / "world_hd"
SHADOWED = ("village_", "decor_stall", "decor_wagon", "decor_forge", "ruins", "mine_entrance")


def footprints(terrain: dict, art: dict) -> list:
    result = [(x, y + 10, 24) for x, y in terrain.get("trees", [])]
    for prop in terrain.get("props", []):
        kind = str(prop.get("kind", ""))
        entry = art.get(f"world_hd/{kind}.png")
        if entry is None or not kind.startswith(SHADOWED) or kind in ("village_lamp", "village_sign", "village_fence_h", "village_fence_v"):
            continue
        x, y = prop["position"]
        result.append((x, y, entry["size"][0] / pack.K * 0.5))
    return result


def build_region(region_id: str, region: dict, art: dict) -> None:
    terrain = region["terrain"]
    t0 = time.time()
    seed = sum(ord(c) for c in region_id) * 31
    gates = [g["position"] for g in region.get("gates", [])]
    img = ground.render(region_id, terrain, seed, footprints(terrain, art), gates)
    img.save(OUT / f"{region_id}_ground.webp", quality=90, method=6)
    cfg = STYLE[terrain.get("art_style", terrain.get("style", "day"))]
    for old in OUT.glob(f"{region_id}_apron_*.webp"):
        old.unlink()
    if cfg.get("apron", True):
        margin = int(terrain.get("edge_margin", 0))
        w, h = terrain["size"]
        island = (margin, margin, w - margin, h - margin) if margin else None
        strips = apron.render(region_id, terrain, gates, seed + 7, cfg.get("sky", "day"), island=island,
                              falls=cfg.get("falls", 3), fall_color=cfg.get("fall_color", (0.7, 0.88, 1.0)),
                              lip_tint=cfg.get("lip_tint", cfg.get("recolor") or (1.0, 1.0, 1.0)),
                              lip_sources=cfg.get("lip"), vines=cfg.get("vines", True))
        for side, strip in strips.items():
            strip.save(OUT / f"{region_id}_apron_{side}.webp", quality=90, method=6)
    minimap.build(region_id, terrain)
    print(f"  {region_id}: ground {img.size[0]}x{img.size[1]}, edges in {time.time() - t0:.1f}s")


def main(argv: list[str]) -> int:
    sprites.build()
    title.build()
    art = json.loads((ROOT / "assets" / "art_manifest.json").read_text())
    regions = json.loads((ROOT / "data" / "regions.json").read_text())
    wanted = argv or [rid for rid, r in regions.items() if r.get("terrain", {}).get("style") in STYLE]
    for region_id in wanted:
        build_region(region_id, regions[region_id], art)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
