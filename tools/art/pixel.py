"""Small pixel-art toolkit on top of numpy (RGBA uint8 canvases)."""
from __future__ import annotations

import math
import pathlib

import numpy as np
from PIL import Image


def hex_color(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def ramp(*values: str) -> list[tuple[int, int, int, int]]:
    return [hex_color(v) for v in values]


class Canvas:
    def __init__(self, width: int, height: int, fill=(0, 0, 0, 0)):
        self.w = width
        self.h = height
        self.px = np.zeros((height, width, 4), dtype=np.uint8)
        self.px[:, :] = fill

    # --- basic drawing -------------------------------------------------
    def inside(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def put(self, x: int, y: int, color) -> None:
        x, y = int(x), int(y)
        if self.inside(x, y):
            if len(color) == 4 and color[3] < 255:
                self.blend(x, y, color)
            else:
                self.px[y, x] = color

    def blend(self, x: int, y: int, color) -> None:
        if not self.inside(x, y):
            return
        a = color[3] / 255.0
        dst = self.px[y, x].astype(np.float32)
        src = np.array(color, dtype=np.float32)
        out_a = a + dst[3] / 255.0 * (1 - a)
        if out_a <= 0:
            return
        rgb = (src[:3] * a + dst[:3] * (dst[3] / 255.0) * (1 - a)) / out_a
        self.px[y, x] = (*np.clip(rgb, 0, 255).astype(np.uint8), int(out_a * 255))

    def get(self, x: int, y: int):
        if not self.inside(x, y):
            return (0, 0, 0, 0)
        return tuple(int(v) for v in self.px[y, x])

    def alpha(self, x: int, y: int) -> int:
        return int(self.px[y, x, 3]) if self.inside(x, y) else 0

    def rect(self, x: int, y: int, w: int, h: int, color) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, color)

    def hline(self, x0: int, x1: int, y: int, color) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, color)

    def vline(self, x: int, y0: int, y1: int, color) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, color)

    def line(self, x0, y0, x1, y1, color) -> None:
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, color) -> None:
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, color)

    def paste(self, other: "Canvas", x: int, y: int, flip: bool = False) -> None:
        src = other.px[:, ::-1] if flip else other.px
        for yy in range(other.h):
            for xx in range(other.w):
                c = src[yy, xx]
                if c[3] == 0:
                    continue
                self.put(x + xx, y + yy, tuple(int(v) for v in c))

    def mask(self) -> np.ndarray:
        return self.px[:, :, 3] > 0

    def outline(self, color, only_outside: bool = True) -> None:
        """Adds a 1px outline around opaque pixels."""
        m = self.mask()
        grown = m.copy()
        grown[1:, :] |= m[:-1, :]
        grown[:-1, :] |= m[1:, :]
        grown[:, 1:] |= m[:, :-1]
        grown[:, :-1] |= m[:, 1:]
        edge = grown & ~m if only_outside else m & ~(
            np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        self.px[edge] = color

    def save(self, path: pathlib.Path | str) -> None:
        path = pathlib.Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.px, "RGBA").save(path, optimize=True)

    def scaled(self, factor: int) -> Image.Image:
        return Image.fromarray(self.px, "RGBA").resize((self.w * factor, self.h * factor), Image.NEAREST)


# --- noise ---------------------------------------------------------------

def value_noise(width: int, height: int, cell: float, seed: int) -> np.ndarray:
    """Smooth value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    gw, gh = int(width / cell) + 3, int(height / cell) + 3
    grid = rng.random((gh, gw))
    ys = np.arange(height) / cell
    xs = np.arange(width) / cell
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    sy = fy * fy * (3 - 2 * fy)
    sx = fx * fx * (3 - 2 * fx)
    a = grid[y0[:, None], x0[None, :]]
    b = grid[y0[:, None], x0[None, :] + 1]
    c = grid[y0[:, None] + 1, x0[None, :]]
    d = grid[y0[:, None] + 1, x0[None, :] + 1]
    top = a + (b - a) * sx[None, :]
    bottom = c + (d - c) * sx[None, :]
    return top + (bottom - top) * sy[:, None]


def fbm(width: int, height: int, cell: float, seed: int, octaves: int = 3) -> np.ndarray:
    total = np.zeros((height, width))
    amplitude, norm = 1.0, 0.0
    for octave in range(octaves):
        total += value_noise(width, height, cell / (2 ** octave), seed + octave * 101) * amplitude
        norm += amplitude
        amplitude *= 0.5
    return total / norm


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def bayer(width: int, height: int) -> np.ndarray:
    return np.tile(BAYER4, (height // 4 + 1, width // 4 + 1))[:height, :width]


def polyline_distance(width: int, height: int, points: list[tuple[float, float]]) -> np.ndarray:
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float32) + 0.5
    best = np.full((height, width), 1e9, dtype=np.float32)
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        dx, dy = bx - ax, by - ay
        length2 = dx * dx + dy * dy or 1.0
        t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / length2, 0, 1)
        px, py = ax + t * dx, ay + t * dy
        best = np.minimum(best, np.hypot(xs - px, ys - py))
    return best


def light_level(nx: float, ny: float, nz: float, light=(-0.55, -0.65, 0.55)) -> float:
    lx, ly, lz = light
    norm = math.sqrt(lx * lx + ly * ly + lz * lz)
    return max(0.0, (nx * lx + ny * ly + nz * lz) / norm)
