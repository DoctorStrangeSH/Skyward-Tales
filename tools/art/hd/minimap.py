"""Detailed minimap: the region's HD ground with every tree, bush, house
and prop drawn in miniature (1/3 world scale; the HUD shows it at 1/6, so
there is detail to spare on bigger windows)."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageEnhance

from hd import pack
from hd.styles import STYLE
from shore_profile import clip_minimap

ROOT = pack.ROOT
SCALE = 3  # world px per minimap px


def build(region_id: str, terrain: dict) -> Path | None:
    ground_path = ROOT / "assets" / "world_hd" / f"{region_id}_ground.webp"
    if not ground_path.exists():
        return None
    art = json.loads((ROOT / "assets" / "art_manifest.json").read_text())
    w, h = terrain["size"]
    image = Image.open(ground_path).convert("RGBA").resize((w // SCALE, h // SCALE), Image.LANCZOS)
    style = terrain.get("style", "day")
    cfg = STYLE.get(style, {})
    things = []
    trees = terrain.get("trees", [])
    n_trees = max(1, len(cfg.get("trees", [])) or 3)
    for index, (x, y) in enumerate(trees):
        variant = abs(int(x) * 7 + int(y) * 13) % n_trees
        if index < len(terrain.get("tree_variants", [])):
            variant = terrain["tree_variants"][index]
        things.append((y + 10, f"{style}_tree_{variant}", x, y + 10))
    n_bush = max(1, len(cfg.get("bushes", [])) or 2)
    for index, (x, y) in enumerate(terrain.get("bushes", [])):
        things.append((y, f"{style}_bush_{index % n_bush}", x, y))
    for prop in terrain.get("props", []):
        x, y = prop["position"]
        things.append((y, str(prop.get("kind", "")), x, y))
    cache: dict = {}
    for _, name, x, y in sorted(things):
        entry = art.get(f"world_hd/{name}.png")
        if entry is None:
            continue
        if name not in cache:
            src = Image.open(ROOT / "assets" / "world_hd" / f"{name}.png").convert("RGBA")
            f = 1.0 / (pack.K * SCALE)
            cache[name] = (src.resize((max(1, round(src.width * f)), max(1, round(src.height * f))), Image.LANCZOS), f)
        small, f = cache[name]
        ox, oy = entry["origin"]
        image.alpha_composite(small, (int(x / SCALE - ox * f), int(y / SCALE - oy * f)))
    inner = ROOT / "assets" / "world_hd" / f"{region_id}_apron_inner.webp"
    if inner.exists():
        image.alpha_composite(Image.open(inner).convert("RGBA").resize(image.size, Image.LANCZOS))
    image = ImageEnhance.Contrast(image).enhance(1.04 if style in ("day", "haven") else 1.08)
    image = ImageEnhance.Color(image).enhance(0.90 if style in ("day", "haven") else 1.12)
    image = clip_minimap(image, terrain)
    out = ROOT / "assets" / "world" / f"{region_id}_mini.png"
    image.save(out, optimize=True)
    return out

