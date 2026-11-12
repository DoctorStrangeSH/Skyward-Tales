"""Use the authored world-space southern coast for minimap transparency."""
from PIL import Image, ImageChops
import numpy as np


def heights(terrain, xs):
    profile = terrain.get("south_shore", [])
    if not profile:
        return np.full_like(xs, terrain["size"][1], dtype=float)
    return np.interp(xs, [p[0] for p in profile], [p[1] for p in profile])


def clip_minimap(image, terrain):
    if not terrain.get("south_shore"):
        return image
    image = image.convert("RGBA")
    w, h = image.size
    ww, wh = terrain["size"]
    coast = heights(terrain, (np.arange(w) + 0.5) * ww / w)
    ys = (np.arange(h) + 0.5) * wh / h
    mask = Image.fromarray((ys[:, None] <= coast[None, :]).astype("uint8") * 255)
    image.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
    return image
