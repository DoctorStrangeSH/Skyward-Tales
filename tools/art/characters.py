"""Chibi humanoid rig: 8 directions x 4 walk frames on a 32x32 grid.

Each body part is a boolean mask shaded with a 4-colour ramp
(light, base, shade, dark). Light comes from the top-left; parts drawn on
top of others get a dark separation edge; the finished sprite gets a tinted
outline. Left-facing rows are mirrors of the right-facing ones.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

from pixel import Canvas, hex_color

SIZE = 32
ORIGIN = (16, 30)
FACINGS = ["down", "down_right", "right", "up_right", "up"]
ROW_ORDER = ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]
MIRROR = {"up_left": "up_right", "left": "right", "down_left": "down_right"}


def r4(*values: str):
    return [hex_color(v) for v in values]


SKIN = r4("#ffdcb8", "#f2b98f", "#d18a6a", "#9c5a4f")


@dataclass
class Look:
    hair: list = field(default_factory=lambda: r4("#d97a4a", "#a8492f", "#7a2f2a", "#4d1f26"))
    hair_style: str = "messy"
    skin: list = field(default_factory=lambda: SKIN)
    top: list = field(default_factory=lambda: r4("#fff4d6", "#e8d3a6", "#bf9f78", "#8a6a55"))
    pants: list = field(default_factory=lambda: r4("#5f74b8", "#43559a", "#2f3c73", "#1f2650"))
    boots: list = field(default_factory=lambda: r4("#9a6a4a", "#704832", "#4e3026", "#33201f"))
    accent: list = field(default_factory=lambda: r4("#6fe0c8", "#2fb09c", "#1f7d78", "#174f57"))
    cape: list | None = None
    robe: bool = False          # long garment that hides the legs
    belt: tuple | None = hex_color("#6b4433")
    buckle: tuple | None = hex_color("#ffd45c")
    beard: list | None = None
    hat: str | None = None      # "cap", "hood", "antlers", "mask"
    hat_colors: list | None = None
    eye: tuple = hex_color("#2a1d33")
    outline: tuple = hex_color("#241a30")
    scarf: bool = True
    staff: list | None = None
    apron: list | None = None
    height_bonus: int = 0
    strap: list | None = None


class Sprite:
    def __init__(self) -> None:
        self.px = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
        self.owner = np.full((SIZE, SIZE), -1, dtype=int)
        self.parts = 0

    def part(self, mask: np.ndarray, ramp, sphere: tuple | None = None, separate: bool = True) -> None:
        """Shades a mask and composites it over what is already drawn."""
        part_id = self.parts
        self.parts += 1
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            left = x > 0 and mask[y, x - 1]
            right = x < SIZE - 1 and mask[y, x + 1]
            up = y > 0 and mask[y - 1, x]
            down = y < SIZE - 1 and mask[y + 1, x]
            if sphere is not None:
                cx, cy, r = sphere
                nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                lit = (-0.6 * nx - 0.7 * ny + 0.5 * nz)
                level = 0 if lit > 0.62 else (1 if lit > 0.12 else 2)
            else:
                level = 1
                if not left or not up:
                    level = 0
                if not right or not down:
                    level = 2
            color = ramp[level]
            if separate and self.px[y, x, 3] and self.owner[y, x] != part_id and (not right or not down):
                color = ramp[min(3, level + 1)]
            self.px[y, x] = color
            self.owner[y, x] = part_id

    def dots(self, points, color) -> None:
        for x, y in points:
            if 0 <= x < SIZE and 0 <= y < SIZE:
                self.px[y, x] = color

    def outline(self, color) -> None:
        m = self.px[:, :, 3] > 0
        grown = m.copy()
        grown[1:, :] |= m[:-1, :]
        grown[:-1, :] |= m[1:, :]
        grown[:, 1:] |= m[:, :-1]
        grown[:, :-1] |= m[:, 1:]
        self.px[grown & ~m] = color

    def canvas(self) -> Canvas:
        c = Canvas(SIZE, SIZE)
        c.px = self.px.copy()
        return c


def ellipse_mask(cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
    ys, xs = np.mgrid[0:SIZE, 0:SIZE] + 0.5
    return ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0


def rect_mask(x0: int, y0: int, x1: int, y1: int, round_bottom: bool = False) -> np.ndarray:
    m = np.zeros((SIZE, SIZE), dtype=bool)
    m[max(0, y0):min(SIZE, y1 + 1), max(0, x0):min(SIZE, x1 + 1)] = True
    if round_bottom and y1 < SIZE:
        m[y1, max(0, x0)] = False
        m[y1, min(SIZE - 1, x1)] = False
    return m


# --- the rig ------------------------------------------------------------------

def draw(look: Look, facing: str, frame: int, pose: str = "walk") -> Canvas:
    s = Sprite()
    side = facing == "right"
    back = facing in ("up", "up_right")
    three_q = facing in ("down_right", "up_right")
    casting = pose == "cast"
    bob = 0 if casting else (1 if frame in (1, 3) else 0)
    stride = 0 if casting else [1, 0, -1, 0][frame]
    hy = 10 - bob - look.height_bonus          # head centre
    ty0, ty1 = 16 - bob, 23 - bob               # torso rows
    cx = 16
    # Soft ground shadow.
    for y in range(28, 32):
        for x in range(8, 25):
            if ((x + 0.5 - 16) / 7.5) ** 2 + ((y + 0.5 - 29.5) / 2) ** 2 <= 1:
                s.px[y, x] = (16, 24, 32, 70)
    shadow_ids = s.px[:, :, 3] > 0
    s.owner[shadow_ids] = -2

    # Cape / hood tail behind the body when facing the camera.
    if look.cape and not back:
        cape = rect_mask(cx - 5, ty0 + 1, cx + 4, ty1 + 2)
        if side:
            cape = rect_mask(cx - 6, ty0, cx - 1, ty1 + 2 - (frame % 2))
        s.part(cape, look.cape)

    # Staff held on the right side (drawn behind when facing away).
    def staff() -> None:
        if not look.staff:
            return
        sx = cx + 7 if not side else cx + 3
        if facing in ("up", "up_right"):
            sx = cx - 7
        m = rect_mask(sx, ty0 - 9, sx, 27 - bob)
        s.part(m, look.staff, separate=False)
        orb = ellipse_mask(sx + 0.5, ty0 - 10, 1.8, 1.8)
        s.part(orb, look.accent, separate=False)

    if back:
        staff()

    # Legs and boots.
    if not look.robe:
        if side:
            positions = [(cx - 1 + stride * 2, 0), (cx - 1 - stride * 2, 0)]
            positions = [(x, 1 if frame in (1, 3) and i == 0 else 0) for i, (x, _) in enumerate(positions)]
            width = 3
        else:
            spread = 3 if not three_q else 2
            lift = [(0, 1), (0, 0), (1, 0), (0, 0)][frame]
            shift = stride if three_q else 0
            positions = [(cx - spread - 1 + shift, lift[0]), (cx + spread - 2 - shift, lift[1])]
            width = 3
        for lx, raised in positions:
            leg = rect_mask(lx, ty1 + 1, lx + width - 1, 27 - raised)
            s.part(leg, look.pants)
            boot = rect_mask(lx - (1 if side and stride >= 0 else 0), 26 - raised, lx + width - 1 + (1 if side else 0), 28 - raised, round_bottom=True)
            s.part(boot, look.boots)

    # Torso (tunic or robe).
    if side:
        torso = rect_mask(cx - 4, ty0, cx + 3, ty1, round_bottom=True)
    else:
        torso = rect_mask(cx - 5, ty0, cx + 4, ty1, round_bottom=True)
    if look.robe:
        hem = 28 - (frame % 2)
        robe = torso | rect_mask(cx - 5 - (0 if side else 1), ty1 - 2, cx + 4 + (0 if side else 1), hem)
        s.part(robe, look.top)
        # Feet peeking out under the hem.
        s.part(rect_mask(cx - 3 + stride, hem, cx - 1 + stride, hem), look.boots, separate=False)
        s.part(rect_mask(cx + 1 - stride, hem, cx + 3 - stride, hem), look.boots, separate=False)
    else:
        s.part(torso, look.top)
    if look.apron and not back:
        s.part(rect_mask(cx - 3 + (1 if side else 0), ty0 + 2, cx + 2 + (1 if side else 0), ty1 + 2), look.apron)
    if look.strap and not back and not side:
        start = cx - 4 if facing == "down" else cx - 3
        s.dots([(start + i, ty0 + 1 + i) for i in range(7)], look.strap[2])
        s.dots([(start + i + 1, ty0 + 1 + i) for i in range(6)], look.strap[1])
    if look.belt and not back:
        s.dots([(x, ty1 - 2) for x in range(cx - 5, cx + 5) if s.px[ty1 - 2, x, 3]], look.belt)
        if look.buckle and not side:
            s.dots([(cx - 1 + (1 if three_q else 0), ty1 - 2)], look.buckle)
    if look.cape and back:
        s.part(rect_mask(cx - 5, ty0, cx + 4, ty1 + 3, round_bottom=True), look.cape)

    # Arms swing opposite to the legs (or reach forward while casting).
    swing = -stride
    if casting:
        _cast_arms(s, look, facing, frame, cx, ty0, ty1)
    elif side:
        arm = rect_mask(cx - 1 + swing * 2, ty0 + 1, cx + 1 + swing * 2, ty1 - 1)
        s.part(arm, look.top)
        s.part(rect_mask(cx - 1 + swing * 2, ty1, cx + 1 + swing * 2, ty1), look.skin, separate=False)
    else:
        arm_y = [0, 0, 0, 0][frame]
        for ax, dy in ((cx - 7, swing if not back else -swing), (cx + 5, -swing if not back else swing)):
            if three_q and ax < cx and not back:
                ax += 1
            arm = rect_mask(ax, ty0 + 1 + max(0, dy) + arm_y, ax + 1, ty1 - 1 + max(0, dy))
            s.part(arm, look.top)
            s.part(rect_mask(ax, ty1 + max(0, dy), ax + 1, ty1 + max(0, dy)), look.skin, separate=False)

    # Scarf (hero) wraps the neck; its tail flutters behind.
    if look.scarf:
        neck = rect_mask(cx - 4 + (1 if side else 0), ty0 - 1, cx + 3, ty0 + 1)
        s.part(neck, look.accent)
        tail_x = cx - 5 if side else (cx + 3 if not back else cx - 4)
        flutter = frame % 2
        s.part(rect_mask(tail_x, ty0 + 1, tail_x + 1, ty0 + 4 + flutter), look.accent)

    # Head.
    head = ellipse_mask(cx, hy, 6.6, 6.1)
    s.part(head, look.skin, sphere=(cx - 1, hy - 1, 7.5), separate=False)
    _hair(s, look, facing, cx, hy, frame)
    if not back:
        _face(s, look, facing, cx, hy)
    _hat(s, look, facing, cx, hy)
    if not back:
        staff()
    s.outline(look.outline)
    if casting:
        _cast_glow(s, look, facing, frame, cx, ty0)
    return s.canvas()


GLOW = r4("#ffffff", "#c8fff4", "#6fe0c8", "#2fb09c")


def _cast_arms(s: Sprite, look: Look, facing: str, frame: int, cx: int, ty0: int, ty1: int) -> None:
    """Frame 0 gathers, 1-2 hold the spell forward, 3 recovers."""
    lift = [1, 3, 3, 1][frame]
    if facing == "right":
        reach = [2, 5, 6, 3][frame]
        s.part(rect_mask(cx, ty0 + 2, cx + reach, ty0 + 3), look.top)
        s.part(rect_mask(cx + reach + 1, ty0 + 2, cx + reach + 1, ty0 + 3), look.skin, separate=False)
    elif facing in ("up", "up_right"):
        for ax in (cx - 7, cx + 5):
            s.part(rect_mask(ax, ty0 - lift, ax + 1, ty0 + 4 - lift), look.top)
            s.part(rect_mask(ax, ty0 - lift - 1, ax + 1, ty0 - lift - 1), look.skin, separate=False)
    else:
        shift = 1 if facing == "down_right" else 0
        for ax in (cx - 5 + shift, cx + 3 + shift):
            s.part(rect_mask(ax, ty0 + 3 - lift + 2, ax + 1, ty1 - lift), look.top)
            s.part(rect_mask(ax, ty1 - lift + 1, ax + 1, ty1 - lift + 1), look.skin, separate=False)


def _hand_point(facing: str, frame: int, cx: int, ty0: int) -> tuple[int, int]:
    lift = [1, 3, 3, 1][frame]
    if facing == "right":
        return cx + [2, 5, 6, 3][frame] + 2, ty0 + 2
    if facing in ("up", "up_right"):
        return cx + (2 if facing == "up_right" else 0), 3 - lift // 3
    return cx + (1 if facing == "down_right" else 0), ty0 + 21 - 16 - lift + 2


def _cast_glow(s: Sprite, look: Look, facing: str, frame: int, cx: int, ty0: int) -> None:
    """Glowing spell orb between the hands and a rune circle under the feet."""
    hx, hy = _hand_point(facing, frame, cx, ty0)
    radius = [1.2, 2.4, 2.8, 1.4][frame]
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x + 0.5 - hx, y + 0.5 - hy)
            if d <= radius:
                s.px[y, x] = GLOW[0] if d < radius * 0.5 else GLOW[1]
            elif d <= radius + 1.5 and s.px[y, x, 3] == 0:
                s.px[y, x] = GLOW[2][:3] + (150,)
    ring = [5.5, 7.5, 8.5, 9.0][frame]
    alpha = [120, 200, 170, 80][frame]
    for y in range(26, SIZE):
        for x in range(SIZE):
            d = math.hypot((x + 0.5 - 16) / ring, (y + 0.5 - 29.5) / (ring * 0.32))
            if 0.82 <= d <= 1.0 and s.owner[y, x] in (-1, -2):
                s.px[y, x] = GLOW[2][:3] + (alpha,)


def cast_sheet(look: Look) -> Canvas:
    out = Canvas(SIZE * 4, SIZE * 8)
    for row, direction in enumerate(ROW_ORDER):
        facing = MIRROR.get(direction, direction)
        for frame in range(4):
            out.paste(draw(look, facing, frame, "cast"), frame * SIZE, row * SIZE, flip=direction in MIRROR)
    return out


def _hair(s: Sprite, look: Look, facing: str, cx: int, hy: float, frame: int) -> None:
    style = look.hair_style
    if style == "bald":
        s.dots([(cx - 3, int(hy) - 4), (cx - 2, int(hy) - 5)], look.skin[0])
        return
    side = facing == "right"
    back = facing in ("up", "up_right")
    cap = ellipse_mask(cx, hy - 1.2, 7.0, 5.6)
    ys, xs = np.mgrid[0:SIZE, 0:SIZE] + 0.5
    if back:
        hair = ellipse_mask(cx, hy, 7.0, 6.6)
        if facing == "up_right":
            hair &= ~((xs > cx + 4.5) & (ys > hy - 1) & (ys < hy + 4))   # ear and cheek show
    elif side:
        hair = cap & (ys < hy - 0.5) | (ellipse_mask(cx, hy, 7.0, 6.6) & (xs < cx - 0.5))
    else:
        # Bangs: zig-zag fringe across the forehead.
        fringe = np.zeros_like(cap)
        shift = 1 if facing == "down_right" else 0
        for x in range(SIZE):
            depth = hy - 2 + (1 if (x + shift) % 3 == 0 else 0) + (1 if (x + shift) % 5 == 1 else 0)
            fringe[: int(depth) + 1, x] = True
        hair = cap & fringe
        hair |= ellipse_mask(cx, hy, 7.0, 6.6) & ((xs < cx - 5.2) | (xs > cx + 5.2)) & (ys < hy + 3)
    if style == "long":
        hair |= rect_mask(cx - 7, int(hy), cx + 6, int(hy) + 9) & ~(rect_mask(cx - 4, int(hy), cx + 3, int(hy) + 9) if not back else np.zeros_like(cap))
        if side:
            hair &= ~rect_mask(cx + 1, int(hy) - 1, cx + 7, int(hy) + 9)
    if style == "messy":
        # A few spiky strands on top.
        for dx, dy in ((-3, -7), (-2, -7), (1, -7), (2, -8), (4, -6)):
            hair[int(hy) + dy, cx + dx] = True
    s.part(hair, look.hair, sphere=(cx - 2, hy - 3, 8.5), separate=False)
    if look.beard and facing != "up":
        beard = ellipse_mask(cx + (2 if side else (1 if facing == "down_right" else 0)), hy + 4.5, 4.5 if not side else 3.5, 3.5)
        beard &= ~ellipse_mask(cx, hy - 1, 9, 4.2)
        if facing == "up_right":
            beard &= rect_mask(cx + 3, 0, SIZE - 1, SIZE - 1)
        s.part(beard, look.beard, separate=False)


def _face(s: Sprite, look: Look, facing: str, cx: int, hy: float) -> None:
    y = int(hy) + 1
    eye, white = look.eye, hex_color("#ffffff")
    blush = look.skin[2][:3] + (150,)
    if facing == "down":
        eyes = [cx - 3, cx + 2]
    elif facing == "down_right":
        eyes = [cx - 1, cx + 4]
    else:
        eyes = [cx + 3]
    for ex in eyes:
        s.dots([(ex, y), (ex, y + 1)], eye)
        s.dots([(ex, y - 1)], look.hair[2]) if look.hair_style != "bald" else None
        s.dots([(ex, y)], white) if facing != "right" else s.dots([(ex, y)], eye)
    if facing == "right":
        s.dots([(cx + 3, y + 1)], eye)
        s.dots([(cx + 4, y)], white)
        s.dots([(cx + 6, y + 1)], look.skin[1])   # nose bump
        s.dots([(cx + 3, y + 3)], look.skin[2])   # mouth corner
        s.dots([(cx - 1, y), (cx - 1, y + 1)], look.skin[2])  # ear
    else:
        mouth_x = cx if facing == "down" else cx + 2
        s.dots([(mouth_x - 1, y + 3), (mouth_x, y + 3)], look.skin[3])
        for ex in eyes:
            bx = ex - 1 if ex < cx else ex + 1
            if 0 <= bx < SIZE:
                s.px[y + 2, bx] = blush


def _hat(s: Sprite, look: Look, facing: str, cx: int, hy: float) -> None:
    if not look.hat:
        return
    colors = look.hat_colors or look.accent
    side = facing == "right"
    back = facing in ("up", "up_right")
    iy = int(hy)
    if look.hat == "cap":
        crown = ellipse_mask(cx, hy - 4, 7.0, 3.6) & rect_mask(0, 0, SIZE - 1, iy - 3)
        s.part(crown, colors)
        brim_x0 = cx - 6 if not side else cx - 4
        brim_x1 = cx + 6 if not side else cx + 9
        s.part(rect_mask(brim_x0, iy - 3, brim_x1, iy - 2), colors[1:] + colors[-1:])
    elif look.hat == "hood":
        hood = ellipse_mask(cx, hy - 0.5, 7.8, 7.4)
        if not back:
            opening = ellipse_mask(cx + (2 if side else (1 if facing == "down_right" else 0)), hy + 1.5, 5.0 if not side else 4.0, 5.2)
            hood &= ~opening
        hood |= rect_mask(cx - 7, iy + 2, cx + 6, iy + 6) & ~ellipse_mask(cx, hy + 2, 5, 5) if not back else rect_mask(cx - 7, iy + 2, cx + 6, iy + 7)
        s.part(hood, colors, sphere=(cx - 2, hy - 3, 9.5), separate=False)
    elif look.hat == "antlers":
        mask = ellipse_mask(cx, hy - 2, 7.2, 5.4) & rect_mask(0, 0, SIZE - 1, iy)
        s.part(mask, colors, separate=False)
        bone = r4("#fff6e0", "#e3d2ae", "#b39f80", "#7a6a58")
        for sign in (-1, 1):
            base = cx + sign * 4
            pts = [(base, iy - 6), (base + sign, iy - 7), (base + sign, iy - 8), (base + sign * 2, iy - 9),
                   (base + sign * 3, iy - 10), (base, iy - 9), (base - sign, iy - 10), (base + sign * 3, iy - 8)]
            m = np.zeros((SIZE, SIZE), dtype=bool)
            for x, y in pts:
                if 0 <= x < SIZE and 0 <= y < SIZE:
                    m[y, x] = True
            s.part(m, bone, separate=False)
    if look.hat in ("antlers", "mask") and not back:
        # Carved wooden mask over the face with glowing eyes.
        mx = cx + (2 if side else (1 if facing == "down_right" else 0))
        mask = ellipse_mask(mx, hy + 1.5, 4.6 if not side else 3.6, 4.4)
        wood = r4("#e8c58c", "#c79a5e", "#94683e", "#5e3f2c")
        s.part(mask, wood, separate=False)
        glow = hex_color("#9cfff0")
        eyes = [mx - 2, mx + 1] if not side else [mx + 1]
        for ex in eyes:
            s.dots([(ex, iy + 1), (ex + (0 if side else 0), iy + 2)], glow)
        s.dots([(mx - 1, iy + 4), (mx, iy + 4)], wood[3])


def sheet(look: Look) -> Canvas:
    out = Canvas(SIZE * 4, SIZE * 8)
    for row, direction in enumerate(ROW_ORDER):
        facing = MIRROR.get(direction, direction)
        for frame in range(4):
            sprite = draw(look, facing, frame)
            out.paste(sprite, frame * SIZE, row * SIZE, flip=direction in MIRROR)
    return out


def portrait_sheet(look: Look) -> Canvas:
    """Idle NPC: facing down, 2 breathing frames, padded to the 4x8 layout."""
    out = Canvas(SIZE * 4, SIZE * 8)
    frames = [draw(look, "down", 0), draw(look, "down", 1)]
    for row, direction in enumerate(ROW_ORDER):
        facing = MIRROR.get(direction, direction)
        for frame in range(4):
            sprite = frames[frame % 2] if direction == "down" else draw(look, facing, 0 if frame % 2 == 0 else 1)
            out.paste(sprite, frame * SIZE, row * SIZE, flip=direction in MIRROR)
    return out


# --- cast list ------------------------------------------------------------------

HERO = Look(cape=r4("#4fa0d8", "#2f72b0", "#244f88", "#1c3560"),
            strap=r4("#c99a5d", "#8f6142", "#5e3d33", "#3f2a2c"))

NPCS = {
    "elder": Look(hair=r4("#f4f4f0", "#d5d6dc", "#a5a8b8", "#6c6f85"), hair_style="long",
                  top=r4("#a1d68b", "#6fae63", "#4a8250", "#2f5640"), robe=True, scarf=False,
                  beard=r4("#ffffff", "#e2e3ea", "#b8bccb", "#80849a"), hat="hood",
                  hat_colors=r4("#7fc77a", "#4f9a5c", "#346f4c", "#234a3b"),
                  staff=r4("#c99a5d", "#8f6142", "#5e3d33", "#3f2a2c"), belt=hex_color("#e3c286"), buckle=None),
    "cartographer": Look(hair=r4("#3e4a7a", "#2c3460", "#1f2448", "#151833"), hair_style="long",
                         top=r4("#ffd98a", "#f0b24e", "#c07f34", "#8a5228"), scarf=False,
                         hat="cap", hat_colors=r4("#c86a4a", "#9c4a3a", "#6e3230", "#4a2028"),
                         pants=r4("#8a6e5a", "#6a5040", "#4c382e", "#33251f")),
    "merchant": Look(hair=r4("#8b5a3c", "#6a3f2c", "#4c2b22", "#331c1a"), hair_style="messy",
                     top=r4("#9fe0a8", "#5cb46e", "#3c8552", "#285a3e"), scarf=False,
                     apron=r4("#f6ead0", "#dcc8a2", "#b39f80", "#7a6a58"),
                     hat="cap", hat_colors=r4("#e86b5a", "#b84a44", "#83333a", "#55222c"),
                     beard=r4("#a06a48", "#7a4c34", "#583428", "#3a2220")),
    "hunter": Look(hair=r4("#5a4636", "#43342a", "#2e241f", "#1e1817"), hair_style="messy",
                   top=r4("#c9a57a", "#9c7a54", "#73573d", "#4c3a2c"), scarf=False,
                   hat="hood", hat_colors=r4("#d8d2c8", "#aaa298", "#7c766e", "#524e4a"),
                   pants=r4("#6a7a52", "#4f5e3c", "#3a462c", "#262e1e"),
                   staff=r4("#c99a5d", "#8f6142", "#5e3d33", "#3f2a2c")),
    "blacksmith": Look(hair_style="bald", top=r4("#9fb0c8", "#71829e", "#4f5c78", "#363f56"), scarf=False,
                       skin=r4("#e8b48c", "#c98d68", "#9c6650", "#6c4240"),
                       apron=r4("#8a5a3c", "#6a4230", "#4c2e24", "#331f1a"),
                       beard=r4("#2e2a30", "#221e24", "#17141a", "#0e0c10"), height_bonus=0),
    "grove_warden": Look(hair=r4("#d9f3ff", "#a9d8ff", "#7aa6e0", "#4f6db0"), hair_style="long",
                         top=r4("#b9f0e0", "#7cc9c0", "#4f969a", "#33646e"), robe=True, scarf=False,
                         hat="cap", hat_colors=r4("#c9a2ff", "#9a72e0", "#6f4fb0", "#4a3480"),
                         staff=r4("#e8e0ff", "#b8a8e8", "#8070b8", "#504880"),
                         accent=r4("#e2fffb", "#8ff7ef", "#3fd6d0", "#1f8a8a"), belt=hex_color("#e2fffb"), buckle=None),
}

SHAMAN = Look(hair=r4("#5a6a4a", "#43503a", "#2e382a", "#1e241e"), hair_style="long",
              top=r4("#7ac7a0", "#4f9a7c", "#33705c", "#224a40"), robe=True, scarf=False,
              hat="antlers", hat_colors=r4("#4f9a7c", "#33705c", "#224a40", "#163028"),
              staff=r4("#c9a07a", "#8f6a4a", "#5e4434", "#3f2c26"),
              accent=r4("#e2fffb", "#9cfff0", "#3fd6d0", "#1f8a8a"),
              outline=hex_color("#10202a"), belt=hex_color("#2e6a5a"), buckle=None)
