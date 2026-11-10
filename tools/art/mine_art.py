#!/usr/bin/env python3
"""Art of the Old Adit (stage 21, step 9) from the owner's sprites.

    python3 tools/art/mine_art.py

Writes assets/world_hd/props/mine_cart.png, mine_timber.png, mine_track.png
(one horizontal piece, 64 px of way) and the copper pickup with anchors in
the manifest. Used by scripts/old_adit.gd.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

M = "dungeons/abandoned_mine/"


def main() -> int:
    K = sprites.K
    manifest_path = pack.ROOT / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    out = sprites.OUT / "props"
    for name, rel, width in (("mine_cart", M + "mine_amethyst_cart", 30), ("mine_timber", M + "mine_timber_support", 62)):
        img, origin = sprites.make(sprites.NS % rel, width)
        img.save(out / f"{name}.png", optimize=True)
        art[f"world_hd/props/{name}.png"] = {"size": [img.width, img.height], "origin": list(origin), "scale": 1.0 / K}
    atlas = pack.image(sprites.NS % (M + "mine_tracks_atlas")).convert("RGBA")
    piece = pack.content(atlas.crop((0, 0, 128, 128)))
    scale = 64 * K / piece.width
    piece = piece.resize((64 * K, round(piece.height * scale)), Image.LANCZOS)
    piece.save(out / "mine_track.png", optimize=True)
    art["world_hd/props/mine_track.png"] = {"size": list(piece.size), "origin": [piece.width // 2, piece.height // 2], "scale": 1.0 / K}
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print("mine art: 3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
