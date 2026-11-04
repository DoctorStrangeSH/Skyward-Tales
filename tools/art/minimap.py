"""Minimap thumbnails: each region's real ground + border foliage, trees and
buildings, shrunk 1/6 with soft averaging, then lightly sharpened so the
paths and water stay readable at HUD size."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

SCALE = 6


def build(root: Path, region_id: str, terrain: dict) -> Path | None:
    ground_path = root / "assets" / "world" / f"{region_id}_ground.png"
    if not ground_path.exists():
        return None
    image = Image.open(ground_path).convert("RGBA")
    canopy = root / "assets" / "world" / f"{region_id}_canopy.png"
    if canopy.exists():
        image.alpha_composite(Image.open(canopy).convert("RGBA"))
    draw = ImageDraw.Draw(image)
    under = terrain.get("style") in ("cave", "crypt", "magma")
    dark = (24, 64, 40, 255) if not under else (40, 36, 60, 255)
    light = (64, 120, 62, 255) if not under else (90, 84, 120, 255)
    for x, y in terrain.get("trees", []):
        draw.ellipse([x - 13, y - 13, x + 13, y + 11], fill=dark)
        draw.ellipse([x - 9, y - 12, x + 7, y + 2], fill=light)
    for prop in terrain.get("props", []):
        kind = str(prop.get("kind", ""))
        if kind.startswith("village_house") or kind.startswith("decor_house") or kind in ("ruins", "sky_archive"):
            x, y = prop["position"]
            draw.rectangle([x - 22, y - 26, x + 22, y + 4], fill=(178, 84, 58, 255))
            draw.rectangle([x - 22, y - 2, x + 22, y + 4], fill=(110, 60, 46, 255))
    small = image.resize((max(1, image.width // SCALE), max(1, image.height // SCALE)), Image.BOX)
    small = ImageEnhance.Contrast(small).enhance(1.15)
    small = ImageEnhance.Color(small).enhance(1.1)
    out = root / "assets" / "world" / f"{region_id}_mini.png"
    small.save(out)
    return out
