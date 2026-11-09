"""Access to the purchased asset pack (assets/incoming/...): loading sprites,
cropping to content, and soft patch synthesis of seamless ground textures."""
from __future__ import annotations

import functools
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
PACK = ROOT / "assets" / "incoming" / "Skyward_Tales_Mega_AssetPack_v1.5" / "Skyward_Tales_Mega_AssetPack_v1.5" / "assets" / "sprites"
# Scale of world art: 2 texture pixels per world pixel.
K = 2


# The owner's new sprites (stage 21, the reference style): read straight from
# the archive in assets/New Sprites. A path "new:<file inside sprites/>".
NEW_ZIP = ROOT / "assets" / "New Sprites" / "Skyward_Tales_All_Sprites.zip"
_new_zip = None


def _new(rel: str) -> Image.Image:
    global _new_zip
    if _new_zip is None:
        import zipfile
        _new_zip = zipfile.ZipFile(NEW_ZIP)
    import io
    return Image.open(io.BytesIO(_new_zip.read("sprites/" + rel))).convert("RGBA")


@functools.lru_cache(maxsize=None)
def image(rel: str) -> Image.Image:
    if rel.startswith("new:"):
        return _new(rel[4:])
    return Image.open(PACK / rel).convert("RGBA")


def array(rel: str) -> np.ndarray:
    return np.asarray(image(rel), dtype=np.float32) / 255.0


def content(img: Image.Image, threshold: int = 24) -> Image.Image:
    """Crops to the opaque part (alpha above threshold) and cleans the faint
    halo the pack's automatic extraction left around many sprites."""
    a = np.asarray(img)[:, :, 3]
    ys, xs = np.nonzero(a > threshold)
    if len(xs) == 0:
        return img
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    out = np.asarray(img.crop(box)).copy()
    alpha = out[:, :, 3].astype(np.float32)
    # Halo: very faint pixels go fully transparent, the rest is steepened.
    alpha = np.clip((alpha - threshold) * 255.0 / (255.0 - threshold) * 1.15, 0, 255)
    out[:, :, 3] = alpha.astype(np.uint8)
    return Image.fromarray(out)


def synthesize(sources: list[tuple[np.ndarray, float]], w: int, h: int, seed: int, patch: int = 64, step: int = 40) -> np.ndarray:
    """Covers a w×h canvas with soft round patches cut from the sources
    (weighted). No tiling seams, no repetition grid."""
    rng = random.Random(seed)
    total = sum(weight for _, weight in sources)
    base = np.mean([src[:, :, :3].reshape(-1, 3).mean(0) for src, _ in sources], axis=0)
    canvas = np.empty((h, w, 3), dtype=np.float32)
    canvas[:] = base
    yy, xx = np.mgrid[0:patch, 0:patch]
    r = np.sqrt((xx - patch / 2 + 0.5) ** 2 + (yy - patch / 2 + 0.5) ** 2) / (patch / 2)
    mask = np.clip((1.0 - r) * 3.0, 0.0, 1.0)[:, :, None]
    for gy in range(-patch // 2, h, step):
        for gx in range(-patch // 2, w, step):
            pick = rng.random() * total
            for src, weight in sources:
                pick -= weight
                if pick <= 0:
                    break
            sh, sw = src.shape[:2]
            sx, sy = rng.randint(0, sw - patch), rng.randint(0, sh - patch)
            piece = src[sy:sy + patch, sx:sx + patch, :3]
            x, y = gx + rng.randint(-step // 3, step // 3), gy + rng.randint(-step // 3, step // 3)
            x0, y0 = max(0, x), max(0, y)
            x1, y1 = min(w, x + patch), min(h, y + patch)
            if x1 <= x0 or y1 <= y0:
                continue
            p = piece[y0 - y:y1 - y, x0 - x:x1 - x]
            m = mask[y0 - y:y1 - y, x0 - x:x1 - x]
            region = canvas[y0:y1, x0:x1]
            region += (p - region) * m
    return canvas


SOURCE = PACK.parent / "source"
ATLASES = {"@1": "skyward_master_atlas.png", "@2": "skyward_secondary_atlas.png"}


@functools.lru_cache(maxsize=None)
def _atlas(key: str) -> np.ndarray:
    return np.asarray(Image.open(SOURCE / ATLASES[key]).convert("RGBA"), dtype=np.float32) / 255.0


def crop(rel: str, box: tuple[int, int, int, int]) -> np.ndarray:
    """A piece of a sprite, or of a master atlas ("@1" / "@2")."""
    src = _atlas(rel) if rel in ATLASES else array(rel)
    return src[box[1]:box[3], box[0]:box[2]]
