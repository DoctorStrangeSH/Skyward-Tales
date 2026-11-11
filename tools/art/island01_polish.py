#!/usr/bin/env python3
"""Rebuild only Greenreach from approved sources. No legacy incoming pack needed."""
from __future__ import annotations
import hashlib
import json
import random
import sys
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import ground, pack, minimap, sprites
from hd.styles import STYLE
from hd.build_hd import footprints

ROOT = pack.ROOT
OUT = ROOT / "assets" / "world_hd"
M, K = 160, pack.K

def southern_sky(terrain: dict, gates: list) -> Image.Image:
    width, height = terrain["size"]
    tw, th = (width + M * 2) * K, M * K
    top = np.array((96, 156, 222), np.float32)
    bottom = np.array((198, 226, 248), np.float32)
    t = (np.arange(th, dtype=np.float32) + (height + M) * K) / ((height + 2 * M) * K - 1)
    rgb = np.broadcast_to((top * (1 - t[:, None]) + bottom * t[:, None])[:, None, :], (th, tw, 3))
    sky = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    rng = random.Random(31017)
    clouds = [OUT / "sky" / (name + ".png") for name in ("cloud_bank", "cloud_tower", "cloud_wisp")]
    for i, x in enumerate(range(-M + 20, width + M, 190)):
        image = pack.content(Image.open(clouds[i % len(clouds)]).convert("RGBA"))
        target = round(rng.uniform(200, 285) * K)
        image = image.resize((target, max(1, round(image.height * target / image.width))), Image.Resampling.LANCZOS)
        sky.alpha_composite(image, (round((x + M) * K), round(rng.uniform(55, 105) * K)))
    # CliffRim owns all southern cliffs and animated water. Only bridges are baked.
    deck = pack.content(pack.image("new:hd/redrawn/islands/rope_bridge.png"))
    for gx, gy in gates:
        edges = {"left": gx, "right": width - gx, "top": gy, "bottom": height - gy}
        if min(edges, key=edges.get) != "bottom" or edges["bottom"] > 120:
            continue
        mid = deck.crop((int(deck.width * 0.3), 0, int(deck.width * 0.7), deck.height)).rotate(90, expand=True)
        length = (M - 18) * K
        image = mid.resize((max(1, round(length * mid.width / mid.height)), length), Image.Resampling.LANCZOS)
        sky.alpha_composite(image, (round((gx + M) * K - image.width / 2), 0))
    return sky

def main() -> int:
    region = json.loads((ROOT / "data/regions.json").read_text(encoding="utf-8"))["greenreach"]
    terrain = region["terrain"]
    manifest = json.loads((ROOT / "assets/art_manifest.json").read_text(encoding="utf-8"))
    gates = [gate["position"] for gate in region.get("gates", [])]
    OUT.mkdir(parents=True, exist_ok=True)
    generated = []
    for index, (source, width) in enumerate(STYLE["day"]["trees"]):
        image, origin = sprites.make(source, width)
        name = f"day_tree_{index}.png"
        image.save(OUT / name, optimize=True)
        manifest["world_hd/" + name] = {"size": list(image.size), "origin": list(origin), "scale": 1.0 / K}
        generated.append("assets/world_hd/" + name)
    (OUT / "props").mkdir(exist_ok=True)
    for name, source in [
        ("waterfall_lip_left", "new:green_reach/base/rocks.png"),
        ("waterfall_lip_right", "new:hd/greenreach/nature/mossy_rocks.png"),
    ]:
        image, origin = sprites.make(source, 20)
        image.save(OUT / "props" / (name + ".png"), optimize=True)
        manifest["world_hd/props/" + name + ".png"] = {"size": list(image.size), "origin": list(origin), "scale": 1.0 / K}
        generated.append("assets/world_hd/props/" + name + ".png")
    (ROOT / "assets/art_manifest.json").write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n", encoding="utf-8")
    surface = ground.render("greenreach", terrain, sum(map(ord, "greenreach")) * 31, footprints(terrain, manifest), gates)
    surface.save(OUT / "greenreach_ground.webp", quality=90, method=6)
    southern_sky(terrain, gates).save(OUT / "greenreach_apron_bottom.webp", quality=90, method=6)
    minimap.build("greenreach", terrain)
    paths = ["assets/world_hd/greenreach_ground.webp", "assets/world_hd/greenreach_apron_bottom.webp", "assets/world/greenreach_mini.png"] + generated
    report = {
        "generator": "tools/art/island01_polish.py",
        "source": str(pack.NEW_ZIP.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": hashlib.sha256(pack.NEW_ZIP.read_bytes()).hexdigest(),
        "ground_size": list(surface.size),
        "baked_waterfalls": 0,
        "outputs": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
    }
    (OUT / "greenreach_art_build.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Greenreach rebuilt: restrained flower clusters; clean sky beneath the animated rim.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
