#!/usr/bin/env python3
"""The southern rim of the floating lands (stage 21, step 12) from the
owner's sprites: cliffs with a grassy lip, ivy, falling water and mist.

    python3 tools/art/cliff_art.py

Writes assets/world_hd/cliffs/*.png at the HD scale (shown at 1/K):
cliff_high, cliff_low (240 world px wide tiles), ivy_a, ivy_b, moss,
waterfall (6x4 frames), mist (6x4 frames). Used by scripts/cliff_rim.gd.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

G = "green_reach/"
TILE = 240


def src(rel: str) -> Image.Image:
    return pack.image(sprites.NS % rel).convert("RGBA")


def fit(img: Image.Image, world_width: float) -> Image.Image:
    scale = world_width * sprites.K / img.width
    return img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)


def sheet(rel: str, cols: int, rows: int, cell_world: float) -> Image.Image:
    img = src(rel)
    w, h = img.width // cols, img.height // rows
    cw = round(cell_world * sprites.K)
    ch = round(h * cw / w)
    out = Image.new("RGBA", (cw * cols, ch * rows))
    for r in range(rows):
        for c in range(cols):
            out.paste(img.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)).resize((cw, ch), Image.LANCZOS), (c * cw, r * ch))
    return out


def main() -> int:
    out = pack.ROOT / "assets" / "world_hd" / "cliffs"
    out.mkdir(parents=True, exist_ok=True)
    fit(src(G + "cliff_edges/cliffs/cliff_straight_high"), TILE).save(out / "cliff_high.png", optimize=True)
    fit(src(G + "cliff_edges/cliffs/cliff_straight_low"), TILE).save(out / "cliff_low.png", optimize=True)
    fit(pack.content(src(G + "cliff_edges/foliage/ivy_double_trail")), 44).save(out / "ivy_a.png", optimize=True)
    fit(pack.content(src(G + "cliff_edges/foliage/ivy_tapered_trail")), 40).save(out / "ivy_b.png", optimize=True)
    fit(pack.content(src(G + "cliff_edges/foliage/moss_drape_flowers")), 70).save(out / "moss.png", optimize=True)
    sheet(G + "water_and_smoke/cliff_waterfall", 6, 4, 26).save(out / "waterfall.png", optimize=True)
    sheet(G + "water_and_smoke/waterfall_mist", 6, 4, 44).save(out / "mist.png", optimize=True)
    print("cliff art: 7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
