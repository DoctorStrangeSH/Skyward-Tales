#!/usr/bin/env python3
"""Village life art (stage 21, step 7) from the owner's new sprites.

    python3 tools/art/village_life_art.py

  assets/sprites/chibi/scout/{idle,walk}.png — the red hood scout (64x72
      cells, rows in the game's order of facings);
  assets/sprites/chibi/hen/{idle,walk,peck}.png — a village hen (64x64);
  assets/world_hd/props/chest_{wood,iron,gold}_{closed,open}.png — chests;
  assets/ui/status/<effect>.png — 32 px effect badges for the HUD.
"""
from __future__ import annotations

import colorsys
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd import pack, sprites  # noqa: E402

ROOT = pack.ROOT
CHIBI = ROOT / "assets" / "sprites" / "chibi"
# Source rows go clockwise from north; the game wants down, down-right,
# right, up-right, up, up-left, left, down-left.
ORDER = [4, 3, 2, 1, 0, 7, 6, 5]
STATUS = ["burn", "curse", "freeze", "haste", "healing", "poison", "regeneration", "shield", "slow", "strength"]


def src(rel: str) -> Image.Image:
    return pack.image(sprites.NS % rel).convert("RGBA")


def rows(sheet: Image.Image, cols: int, count: int) -> list[list[Image.Image]]:
    w, h = sheet.width // cols, sheet.height // count
    return [[sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)) for c in range(cols)] for r in range(count)]


def write(folder: Path, anim: str, frames: list[list[Image.Image]]) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    w, h = frames[0][0].size
    out = Image.new("RGBA", (w * len(frames[0]), h * len(frames)))
    for r, row in enumerate(frames):
        for c, frame in enumerate(row):
            out.paste(frame, (c * w, r * h))
    out.save(folder / f"{anim}.png", optimize=True)


def feet(frames: list[list[Image.Image]]) -> int:
    alpha = np.asarray(frames[0][0])[:, :, 3]
    return int(np.nonzero(alpha.max(axis=1) > 128)[0].max()) + 1


def hue_shift(img: Image.Image, to_hue: float | None, sat: float, val: float) -> Image.Image:
    a = np.asarray(img).astype(np.float32) / 255.0
    out = a.copy()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            if a[y, x, 3] < 0.02:
                continue
            h, s, v = colorsys.rgb_to_hsv(*a[y, x, :3])
            # Recolour the wood only: the gold trim and gems stay.
            if 0.0 <= h <= 0.09 and s > 0.3:
                h = to_hue if to_hue is not None else h
                s, v = s * sat, min(1.0, v * val)
                out[y, x, :3] = colorsys.hsv_to_rgb(h, s, v)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def main() -> int:
    manifest_path = CHIBI / "manifest.json"
    chibi = json.loads(manifest_path.read_text())
    # The scout.
    idle = rows(src("characters/red_hood_scout/red_hood_scout_idle_8dir"), 4, 2)
    idle8 = [[frame] for row in idle for frame in row]
    walk = rows(src("characters/red_hood_scout/red_hood_scout_walk_8dir"), 4, 8)
    scout_idle = [idle8[i] for i in ORDER]
    scout_walk = [walk[i] for i in ORDER]
    write(CHIBI / "scout", "idle", scout_idle)
    write(CHIBI / "scout", "walk", scout_walk)
    chibi["scout"] = {"anims": {"idle": 1, "walk": 4}, "cell": [64, 72], "feet": feet(scout_idle), "scale": 0.62, "filter": "linear"}
    # The hen.
    hen = rows(src("characters/village_hen/village_hen_walk_8dir"), 4, 8)
    hen_walk = [hen[i] for i in ORDER]
    peck = rows(src("characters/village_hen/village_hen_peck_s"), 4, 1)[0]
    write(CHIBI / "hen", "walk", hen_walk)
    write(CHIBI / "hen", "idle", [[row[0]] for row in hen_walk])
    write(CHIBI / "hen", "peck", [peck for _ in range(8)])
    chibi["hen"] = {"anims": {"idle": 1, "walk": 4, "peck": 4}, "cell": [64, 64], "feet": feet(hen_walk), "scale": 0.36, "filter": "linear"}
    manifest_path.write_text(json.dumps(dict(sorted(chibi.items())), indent=1) + "\n")

    # Chests: the pack's chest in three tiers.
    art_path = ROOT / "assets" / "art_manifest.json"
    art = json.loads(art_path.read_text())
    out = sprites.OUT / "props"
    for state in ("closed", "open"):
        base = pack.content(src(f"props/treasure_chest/chest_{state}"))
        for tier, (hue, sat, val, width) in {"wood": (None, 1.0, 1.0, 24), "iron": (0.6, 0.35, 0.95, 26), "gold": (0.12, 1.0, 1.25, 28)}.items():
            img = hue_shift(base, hue, sat, val)
            scale = width * sprites.K / img.width
            img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
            img.save(out / f"chest_{tier}_{state}.png", optimize=True)
            art[f"world_hd/props/chest_{tier}_{state}.png"] = {"size": [img.width, img.height], "origin": [img.width // 2, img.height - 3], "scale": 1.0 / sprites.K}
    art_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")

    # Effect badges.
    status_dir = ROOT / "assets" / "ui" / "status"
    status_dir.mkdir(parents=True, exist_ok=True)
    for name in STATUS:
        pack.content(src(f"ui/status_icons/{name}_242")).resize((32, 32), Image.LANCZOS).save(status_dir / f"{name}.png", optimize=True)
    print("village life art: scout, hen, 6 chests,", len(STATUS), "badges")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
