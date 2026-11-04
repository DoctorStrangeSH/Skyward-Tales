"""Lava recolours of existing enemy sheets for the Ashen Waste: luminance is
mapped onto a charcoal → ember ramp, the brightest parts glow."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

EMBER = np.array([(16, 10, 12), (34, 24, 26), (58, 42, 40), (88, 62, 54), (210, 92, 34), (255, 170, 70), (255, 232, 150)], dtype=np.float32)
OBSIDIAN = np.array([(14, 10, 14), (28, 22, 28), (46, 36, 42), (70, 54, 58), (120, 60, 40), (232, 110, 40), (255, 200, 110)], dtype=np.float32)


def lava(src: Path, dst: Path, ramp: np.ndarray = EMBER, glow_share: float = 0.15) -> None:
    image = np.array(Image.open(src).convert("RGBA")).astype(np.float32)
    rgb = image[..., :3] / 255.0
    lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    opaque = image[..., 3] > 0
    low, glow_from = np.quantile(lum[opaque], [0.02, 1.0 - glow_share])
    lum = (lum - low) / max(1e-3, 1.0 - low)
    glow_from = (glow_from - low) / max(1e-3, 1.0 - low)
    # Stretch so the dark body stays dark and highlights become embers.
    level = np.clip(lum, 0, 1)
    idx = np.where(level < glow_from, level / glow_from * 3.99, 4 + (level - glow_from) / (1 - glow_from) * 2.99)
    idx = np.clip(idx, 0, len(ramp) - 1).astype(int)
    out = image.copy()
    out[..., :3] = ramp[idx]
    Image.fromarray(out.astype(np.uint8)).save(dst)


GOLD = np.array([(40, 26, 14), (90, 58, 22), (150, 100, 34), (200, 150, 50), (240, 196, 80), (255, 230, 130), (255, 252, 220)], dtype=np.float32)


LIGHT = np.array([(70, 60, 90), (120, 110, 150), (170, 170, 210), (210, 220, 245), (255, 236, 160), (255, 248, 210), (255, 255, 255)], dtype=np.float32)


def build(root: Path) -> None:
    enemies = root / "assets" / "sprites" / "enemies"
    lava(enemies / "forest_wolf_8dir.png", enemies / "ember_hound_8dir.png", OBSIDIAN, 0.07)
    lava(enemies / "stone_golem_8dir.png", enemies / "magma_golem_8dir.png", OBSIDIAN, 0.12)
    lava(enemies / "echo_warden_8dir.png", enemies / "pattern_voice_8dir.png", LIGHT, 0.3)
    lava(enemies / "cave_bat_8dir.png", enemies / "loot_imp_8dir.png", GOLD, 0.25)
    lava(enemies / "mountain_giant_8dir.png", enemies / "ash_lord_8dir.png", OBSIDIAN, 0.1)


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[2])
