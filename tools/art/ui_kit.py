#!/usr/bin/env python3
"""Interface frames in the owner's gold-and-navy style (stage 21).

    python3 tools/art/ui_kit.py

Nine-slice frames for UiStyle (scripts/ui_style.gd), cut from the owner's
UI kits in assets/New Sprites (Inventory, Dialogue): the art is halved
(the interface is laid out at 640×360) and reduced to corners plus thin
edge and centre strips. Buttons are drawn here in the same palette —
the kit's own buttons are too tall for the game's small rows.
  assets/ui/panel.png        — windows and HUD frames (margin 8)
  assets/ui/panel_gold.png   — dialogue and big windows (margin 14)
  assets/ui/button_*.png     — buttons (margin 4)
"""
from __future__ import annotations

import io
import pathlib
import zipfile

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
KITS = ROOT / "assets" / "New Sprites"
OUT = ROOT / "assets" / "ui"


def kit_image(kit: str, name: str) -> Image.Image:
    with zipfile.ZipFile(KITS / f"Skyward_Tales_{kit}.zip") as z:
        path = next(n for n in z.namelist() if n.endswith("/" + name))
        return Image.open(io.BytesIO(z.read(path))).convert("RGBA")


def nine(src: Image.Image, margin: int, scale: float = 0.5, mid: int = 8) -> Image.Image:
    """Corners of the (scaled) frame with short straight strips between."""
    img = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
    w, h = img.size
    size = margin * 2 + mid
    out = Image.new("RGBA", (size, size))
    cx, cy = w // 2 - mid // 2, h // 2 - mid // 2
    xs = [(0, margin, 0), (cx, cx + mid, margin), (w - margin, w, margin + mid)]
    ys = [(0, margin, 0), (cy, cy + mid, margin), (h - margin, h, margin + mid)]
    for x0, x1, dx in xs:
        for y0, y1, dy in ys:
            out.paste(img.crop((x0, y0, x1, y1)), (dx, dy))
    return out


NAVY, NAVY_L, GOLD, GOLD_L, GOLD_D = (22, 22, 46), (36, 38, 74), (214, 150, 60), (255, 214, 120), (120, 76, 30)


def button(state: str) -> Image.Image:
    img = Image.new("RGBA", (12, 12))
    d = ImageDraw.Draw(img)
    fill = {"normal": NAVY, "hover": NAVY_L, "pressed": (20, 52, 54), "disabled": (30, 30, 38)}[state]
    edge = {"normal": GOLD, "hover": GOLD_L, "pressed": GOLD_L, "disabled": (96, 88, 80)}[state]
    d.rectangle((1, 1, 10, 10), fill=GOLD_D + (255,) if state != "disabled" else (60, 56, 52, 255))
    d.rectangle((1, 0, 10, 11), fill=edge + (255,))
    d.rectangle((0, 1, 11, 10), fill=edge + (255,))
    d.rectangle((1, 1, 10, 10), fill=fill + (255,))
    # A lit top edge and a shaded foot.
    d.line((2, 1, 9, 1), fill=tuple(min(255, c + 26) for c in fill) + (255,))
    d.line((2, 10, 9, 10), fill=tuple(max(0, c - 10) for c in fill) + (255,))
    for x, y in ((0, 0), (11, 0), (0, 11), (11, 11)):
        img.putpixel((x, y), (0, 0, 0, 0))
    return img


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    nine(kit_image("Inventory_UI", "tooltip_panel.png"), 8).save(OUT / "panel.png")
    nine(kit_image("Dialogue_UI", "journal_panel.png"), 14).save(OUT / "panel_gold.png")
    for state in ("normal", "hover", "pressed", "disabled"):
        button(state).save(OUT / f"button_{state}.png")
    print("  ui: panel, panel_gold, buttons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
