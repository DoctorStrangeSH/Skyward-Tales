#!/usr/bin/env python3
"""The HD heroine (stage 21) from the owner's painted sheets.

    python3 tools/art/hero_hd.py

Sources (tools/art/sources, the owner's own art): an 8-direction idle
sheet (8 frames) and an 8-direction run sheet (9 frames), rows in the
game's order — down, down-right, right, up-right, up, up-left, left,
down-left. The frames are cut by their real bands, cleaned (stray
low-alpha specks), scaled and stood on one foot line in a 128×128 cell
(shown at 0.5 with a linear filter, like the HD world).

The sheets hold only idle and run; the other animations the game plays
are built from those frames: slash1/slash2 (a lunge with a blade arc),
spin (the eight facings in a whirl), cast (a lean and a glow at the
hands), charge (a crouch with gathering light), hit (a recoil with a red
flash), roll (a tucked spin), faint (falling over).
Output: assets/sprites/chibi/hero_f/*.png and its manifest entry.
"""
from __future__ import annotations

import json
import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "art" / "sources"
OUT = ROOT / "assets" / "sprites" / "chibi"
CELL = 128
FEET = 108          # the foot line inside the cell
HEIGHT = 72.0       # the idle figure's height in the cell (36 world px)
# Screen vectors of the eight rows.
DIRS = [(0, 1), (0.7, 0.7), (1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7)]


def bands(v: np.ndarray, thr: int = 3) -> list[tuple[int, int]]:
    on = v > thr
    out, start = [], None
    for i, x in enumerate(on):
        if x and start is None:
            start = i
        if not x and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(v)))
    return out


def cut(path: pathlib.Path, cols: int, rows: int, scale: float | None = None) -> tuple[list[list[Image.Image]], float]:
    """Frames [row][col] placed in the cell: centred by mass, feet on the line."""
    sheet = Image.open(path).convert("RGBA")
    a = np.array(sheet)
    # Stray specks around the figures: keep solid pixels and their soft edge.
    alpha = a[..., 3].astype(np.float32)
    solid = Image.fromarray(((alpha > 110) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    a[..., 3] = np.minimum(a[..., 3], np.array(solid))
    a[a[..., 3] < 24] = 0
    mask = a[..., 3] > 60
    col_bands, row_bands = bands(mask.sum(0)), bands(mask.sum(1))
    assert len(col_bands) == cols and len(row_bands) == rows, (path.name, len(col_bands), len(row_bands))
    if scale is None:
        scale = HEIGHT / float(np.median([b - t for t, b in row_bands]))
    clean = Image.fromarray(a)
    out: list[list[Image.Image]] = []
    for top, bottom in row_bands:
        row: list[Image.Image] = []
        for left, right in col_bands:
            frame = clean.crop((left - 6, top - 6, right + 6, bottom + 2))
            fa = np.array(frame)[..., 3] > 60
            ys, xs = np.nonzero(fa)
            if len(xs) == 0:
                row.append(Image.new("RGBA", (CELL, CELL)))
                continue
            # Centre on the body's mass, stand on the lowest pixel of the row band.
            cx = float(np.mean(xs))
            small = frame.resize((max(1, round(frame.width * scale)), max(1, round(frame.height * scale))), Image.LANCZOS)
            cell = Image.new("RGBA", (CELL, CELL))
            x = round(CELL / 2 - cx * scale)
            y = round(FEET - (frame.height - 2) * scale)
            cell.alpha_composite(small, (x, max(0, y)) if y >= 0 else (x, 0), (0, 0) if y >= 0 else (0, -y))
            row.append(cell)
        out.append(row)
    return out, scale


def sheet_of(frames: list[list[Image.Image]]) -> Image.Image:
    rows, cols = len(frames), len(frames[0])
    img = Image.new("RGBA", (cols * CELL, rows * CELL))
    for r in range(rows):
        for c in range(cols):
            img.paste(frames[r][c], (c * CELL, r * CELL))
    return img


def moved(frame: Image.Image, dx: float = 0, dy: float = 0, angle: float = 0, sx: float = 1, sy: float = 1,
          tint=None, alpha: float = 1.0) -> Image.Image:
    """The frame shifted, turned about the body and squashed from the feet."""
    img = frame
    if sx != 1 or sy != 1:
        w, h = max(1, round(CELL * sx)), max(1, round(CELL * sy))
        scaled = frame.resize((w, h), Image.BICUBIC)
        img = Image.new("RGBA", (CELL, CELL))
        img.alpha_composite(scaled.crop((max(0, (w - CELL) // 2), max(0, h - CELL), max(0, (w - CELL) // 2) + min(w, CELL), h)),
                            (max(0, (CELL - w) // 2), max(0, round(FEET - FEET * sy))) if h <= CELL else (max(0, (CELL - w) // 2), 0))
    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC, center=(CELL / 2, FEET - 34))
    if dx or dy:
        img = img.transform((CELL, CELL), Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BICUBIC)
    if tint is not None:
        a = np.array(img).astype(np.float32)
        r, g, b, k = tint
        a[..., 0] = a[..., 0] * (1 - k) + r * k
        a[..., 1] = a[..., 1] * (1 - k) + g * k
        a[..., 2] = a[..., 2] * (1 - k) + b * k
        img = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    if alpha < 1.0:
        a = np.array(img)
        a[..., 3] = (a[..., 3] * alpha).astype(np.uint8)
        img = Image.fromarray(a)
    return img


def arc(d: tuple[float, float], start: float, sweep: float, radius: float = 44, width: float = 9,
        color=(255, 246, 214), strength: float = 1.0) -> Image.Image:
    """A blade trail: a crescent around the body, widest in the middle."""
    k = 4
    layer = Image.new("RGBA", (CELL * k, CELL * k))
    draw = ImageDraw.Draw(layer)
    facing = math.degrees(math.atan2(d[1], d[0]))
    cx, cy = CELL / 2 * k, (FEET - 34) * k
    steps = 26
    for i in range(steps):
        t = i / (steps - 1)
        ang = math.radians(facing + start + sweep * t)
        thick = width * math.sin(math.pi * t) ** 0.8 * k
        r = radius * k
        x, y = cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.82
        a = int(255 * strength * (0.25 + 0.75 * t))
        draw.ellipse((x - thick, y - thick * 0.8, x + thick, y + thick * 0.8), fill=color + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(k * 1.2)).resize((CELL, CELL), Image.LANCZOS)
    return layer


def glow(at: tuple[float, float], radius: float, color=(255, 240, 190), strength: float = 1.0) -> Image.Image:
    layer = Image.new("RGBA", (CELL, CELL))
    draw = ImageDraw.Draw(layer)
    for i in range(8, 0, -1):
        r = radius * i / 8
        draw.ellipse((at[0] - r, at[1] - r, at[0] + r, at[1] + r), fill=color + (int(strength * 255 * (1 - i / 9) ** 1.6),))
    return layer.filter(ImageFilter.GaussianBlur(1.2))


def under(top: Image.Image, below: Image.Image) -> Image.Image:
    out = below.copy()
    out.alpha_composite(top)
    return out


def over(base: Image.Image, layer: Image.Image) -> Image.Image:
    out = base.copy()
    out.alpha_composite(layer)
    return out


def build() -> dict[str, list[list[Image.Image]]]:
    idle, scale = cut(SRC / "hero_f_idle_8x8.png", 8, 8)
    run, _ = cut(SRC / "hero_f_run_9x8.png", 9, 8, scale)
    anims: dict[str, list[list[Image.Image]]] = {"idle": idle, "walk": run}
    slash1, slash2, cast, charge, hit, roll, spin, faint = [], [], [], [], [], [], [], []
    for r, d in enumerate(DIRS):
        base = idle[r][0]
        stride = run[r][2]
        side = 1 if d[0] >= 0 else -1
        # A lunge along the facing with a blade trail sweeping across it.
        lunge = [(-3, 4), (5, -6), (11, -10), (12, -8), (7, -3), (2, 0)]
        row1, row2 = [], []
        for i, (push, lean) in enumerate(lunge):
            pose = moved(stride if 1 <= i <= 3 else base, d[0] * push, d[1] * push * 0.7, lean * side * 0.6)
            if 1 <= i <= 4:
                t = (i - 1) / 3
                trail1 = arc(d, -95 + 60 * t, 110, strength=1.0 - 0.25 * i / 4)
                trail2 = arc(d, 95 - 60 * t, -110, color=(214, 240, 255), strength=1.0 - 0.25 * i / 4)
                behind = d[1] < -0.3
                row1.append(under(pose, trail1) if behind else over(pose, trail1))
                row2.append(under(pose, trail2) if behind else over(pose, trail2))
            else:
                row1.append(pose)
                row2.append(pose)
        slash1.append(row1)
        slash2.append(row2)
        # Casting: lean back, then forward with light at the hands.
        hands = (CELL / 2 + d[0] * 22, FEET - 40 + d[1] * 14)
        cast.append([
            moved(base, -d[0] * 2, -d[1] * 1.5),
            over(moved(base, -d[0] * 3, -d[1] * 2, sy=1.02), glow(hands, 10, strength=0.6)),
            over(moved(base, d[0] * 2, d[1] * 1.5, sy=1.03), glow(hands, 17, strength=0.9)),
            over(moved(base, d[0] * 4, d[1] * 3), glow(hands, 22, strength=1.0)),
            over(moved(base, d[0] * 1, d[1] * 1), glow(hands, 12, strength=0.45)),
        ])
        # Charging: a crouch with gathering light at the feet.
        charge.append([
            under(moved(base, sy=sy, sx=2 - sy), glow((CELL / 2, FEET - 6), 20 + 5 * i, color=(190, 224, 255), strength=0.35 + 0.12 * i))
            for i, sy in enumerate([0.97, 0.94, 0.92, 0.94])
        ])
        # Hit: thrown back, flashing red.
        hit.append([moved(base, -d[0] * k, -d[1] * k * 0.7, -lean * side, tint=(255, 60, 50, t))
                    for k, lean, t in [(5, 6, 0.55), (8, 9, 0.38), (4, 4, 0.18), (1, 0, 0.0)]])
        # Roll: tucked and turning, travelling with the dodge.
        turn = -side if abs(d[0]) > 0.3 else (1 if d[1] > 0 else -1)
        roll.append([moved(base if i in (0, 9) else stride, 0, -6 * math.sin(math.pi * i / 9), turn * 40 * i,
                           sx=0.8 if 0 < i < 9 else 1.0, sy=0.8 if 0 < i < 9 else 1.0) for i in range(10)])
        # Spin: the eight facings in a whirl, a ring of steel around.
        ring = []
        for i in range(8):
            pose = idle[(r + i) % 8][0]
            sweep = arc(DIRS[(r + i) % 8], -150, 300, radius=46, width=7, strength=0.85)
            ring.append(over(under(pose, arc(DIRS[(r + i + 4) % 8], -60, 120, radius=46, width=6, strength=0.5)), sweep) if i % 2 == 0
                        else under(pose, sweep))
        spin.append(ring)
        # Fainting: sinks and falls to the side.
        fall = []
        for i in range(12):
            t = min(1.0, i / 7)
            fall.append(moved(base, side * 10 * t, 4 * t, -side * 86 * t * t, tint=(120, 120, 150, 0.25 * t)))
        faint.append(fall)
    anims.update({"slash1": slash1, "slash2": slash2, "cast": cast, "charge": charge, "hit": hit, "roll": roll,
                  "spin": spin, "faint": faint})
    return anims


def main() -> int:
    anims = build()
    folder = OUT / "hero_f"
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    for name, frames in anims.items():
        sheet_of(frames).save(folder / f"{name}.png")
        print(f"  hero_f/{name}.png  {len(frames[0])} frames")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["hero_f"] = {"anims": {k: len(v[0]) for k, v in sorted(anims.items())}, "cell": [CELL, CELL], "feet": FEET,
                          "scale": 0.5, "filter": "linear"}
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
