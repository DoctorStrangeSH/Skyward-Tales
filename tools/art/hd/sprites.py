"""HD world sprites from the asset pack: trees, bushes, houses and props.

Each sprite is cropped to its content, cleaned of the extraction halo,
resized to K texture pixels per world pixel and saved as
assets/world_hd/<name>.png. The game draws world_hd art instead of the
world/ art of the same name, at scale 1/K (scripts/world.gd, WorldArt).

Widths are in world pixels; most match the old art so collision footprints
in data/regions.json keep fitting.

Run: python3 tools/art/hd/sprites.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from hd import pack  # noqa: E402
from hd.styles import STYLE  # noqa: E402

ROOT = pack.ROOT
OUT = ROOT / "assets" / "world_hd"
K = pack.K
B = "buildings/%s.png"
P = "props/%s.png"
W = "workshops/%s.png"
S = "skylands/%s.png"
N2 = "nature/%s.png"
# Stage 21: the owner's new sprites (assets/New Sprites), see hd/pack.py.
NS = "new:%s.png"

# name: (pack file, world width, roof hue (None = keep), origin y-fraction from the bottom of content)
BUILDINGS = {
    "village_house_small": (NS % "hd/redrawn/settlement/cottage", 84, None),
    "village_house_wine": (NS % "hd/greenreach/village/cottage", 86, None),
    "village_house_blue": (NS % "hd/redrawn/settlement/cottage", 80, 0.6),
    "village_house_slate": (NS % "hd/greenreach/village/cottage", 88, 0.58),
    "village_house_moss": (NS % "hd/redrawn/settlement/cottage", 92, 0.3),
    "village_house_large": (NS % "hd/redrawn/settlement/inn", 108, None),
    "village_house_long": (NS % "hd/redrawn/settlement/inn", 116, 0.58),
    "village_hall": (NS % "hd/redrawn/settlement/watchtower", 124, None),
    "village_tavern_1": (NS % "hd/redrawn/settlement/inn", 108, None),
    "village_tavern_2": (NS % "hd/redrawn/settlement/inn", 118, None),
    "village_library_1": (B % "arcane_shop", 90, None),
    "village_library_2": (B % "buildings_extra_003", 96, None),
    "village_guild_1": (W % "buildings/buildings_005", 104, None),
    "village_guild_2": (B % "stone_cathedral", 106, None),
    "village_home_1": (NS % "hd/greenreach/village/cottage", 84, 0.08),
    "village_home_2": (NS % "hd/redrawn/settlement/cottage", 94, 0.08),
    "village_windmill": (B % "windmill_house", 84, None),
    "village_arch": (B % "flower_arch_gate", 64, None),
    "village_market_red": (NS % "hd/redrawn/settlement/market_stall", 68, None),
    "village_market_green": (NS % "hd/redrawn/settlement/market_stall", 68, 0.33),
    "decor_stall_white": (W % "resources_market/resources_market_001", 66, None),
    "decor_stall_blue": (NS % "hd/sky_harbor/harbor/ticket_kiosk", 60, None),
    "decor_stall_orange": (NS % "hd/redrawn/settlement/market_stall", 68, 0.08),
    "decor_wagon": (NS % "hd/greenreach/village/merchant_cart", 66, None),
    "decor_forge": (NS % "hd/greenreach/sky/village_forge", 64, None),
    "village_well": (NS % "hd/redrawn/settlement/well", 42, None),
    "village_lamp": (NS % "green_reach/base/lantern", 17, None),
    "village_sign": (NS % "hd/sky_harbor/road/trail_signpost", 26, None),
    "village_board": (NS % "hd/sky_harbor/road/notice_board", 38, None),
    "village_fence_h": (NS % "hd/greenreach/village/wood_fence", 38, None),
    "village_hay": (W % "resources_market/resources_market_036", 26, None),
    "decor_potted_plant": (NS % "hd/greenreach/village/flower_planter", 22, None),
    "ruins": (S % "sky_ruins/sky_ruin_006", 104, None),
    "mine_entrance": (P % "props_extra_010", 72, None),
    "village_flowers_a": (NS % "green_reach/base/flowers_gold", 30, None),
    "village_flowers_b": (NS % "green_reach/base/flowers_white", 28, None),
    "village_flowers_c": (NS % "hd/sky_harbor/flora/lupines", 22, None),
    "decor_armor_stand": (W % "forges_tools/forges_tools_012", 16, None),
    "decor_weapon_rack": (W % "forges_tools/forges_tools_008", 26, None),
    "decor_workbench": (W % "tailor_wood_mason/tailor_wood_mason_013", 32, None),
    "village_bench": (NS % "hd/sky_harbor/road/flowered_bench", 32, None),
    "gather_wood": (NS % "hd/sky_harbor/flora/mossy_log", 30, None),
    "gather_stone": (NS % "hd/greenreach/nature/mossy_rocks", 28, None),
    "gather_iron": ("crystals/crystal_ores/crystal_ore_027.png", 28, None),
    "gather_healroot": ("nature/nature_extra_029.png", 18, None),
    "gather_bluebell": ("crystals/arcane_flora/arcane_flora_025.png", 18, None),
}


C = "crystals/%s.png"
D = "dungeons/%s.png"
R = "workshops/resources_market/resources_market_%03d.png"
# Gameplay props (props/<name>.png in the game): pack file, world width, tint.
PROPS = {
    "chest_gold_closed": (NS % "hd/greenreach/village/blue_gold_chest", 30, None),
    "chest_gold_open": (NS % "props/treasure_chest/chest_open", 30, None),
    "chest_iron_closed": (NS % "hd/redrawn/dungeon/ironbound_chest", 28, None),
    "chest_iron_open": (NS % "props/treasure_chest/chest_open", 28, "iron"),
    "chest_wood_closed": (NS % "props/treasure_chest/chest_closed", 26, None),
    "chest_wood_open": (NS % "props/treasure_chest/chest_open", 26, None),
    "chest_closed": (NS % "props/treasure_chest/chest_closed", 24, None),
    "chest_open": (NS % "props/treasure_chest/chest_open", 24, None),
    "waystone_on": (NS % "hd/sky_harbor/road/wayshrine", 30, None),
    "waystone_off": (NS % "hd/sky_harbor/road/wayshrine", 30, "dim"),
    "lore_stone": (C % "shrines_obelisks/crystal_shrine_009", 22, None),
    "moonleaf": (C % "arcane_flora/arcane_flora_024", 16, None),
    "spirit_blossom": (C % "arcane_flora/arcane_flora_018", 20, None),
    "marsh_lantern": (C % "arcane_flora/arcane_flora_021", 20, None),
    "echo_crystal": (C % "shrines_obelisks/crystal_shrine_015", 12, None),
    "memory_crystal": (C % "shrines_obelisks/crystal_shrine_016", 14, None),
    "keeper_echo": (C % "shrines_obelisks/crystal_shrine_018", 14, None),
    "pattern_core": (C % "shrines_obelisks/crystal_shrine_019", 14, None),
    "wind_rune": (C % "shrines_obelisks/crystal_shrine_020", 14, None),
    "relic": (C % "shrines_obelisks/crystal_shrine_012", 16, None),
    "sky_shard": (C % "crystal_ores/crystal_ore_029", 16, None),
    "ore_node": (C % "crystal_ores/crystal_ore_023", 28, None),
    "meteor_iron": (C % "crystal_ores/crystal_ore_027", 28, None),
    "ember_coal": (C % "crystal_ores/crystal_ore_022", 22, None),
    "supply_crate": (NS % "hd/sky_harbor/road/travel_cache", 26, None),
    "coal_sack": (R % 39, 18, None),
    "flour_sack": (R % 44, 16, None),
    "map_fragment": (R % 27, 18, None),
    "lost_letter": (R % 28, 15, None),
    "song_scroll": (R % 20, 14, None),
    "loot_coins": (R % 22, 14, None),
    "pouch": (R % 3, 13, None),
    "lever_off": (D % "chests_sarcophagi/chests_sarcophagi_013", 22, None),
    "lever_on": (D % "chests_sarcophagi/chests_sarcophagi_012", 22, None),
    "gate_bridge_h": (NS % "hd/redrawn/islands/rope_bridge", 48, None),
    "gate_bridge_v": ("skylands/bridges_arches/sky_bridge_007.png", 52, None),
    "gate_day": ("skylands/bridges_arches/sky_bridge_007.png", 40, None),
    "gate_coast": ("skylands/bridges_arches/sky_bridge_007.png", 40, None),
    "gate_marsh": ("skylands/bridges_arches/sky_bridge_007.png", 40, None),
    "gate_mountain": ("skylands/bridges_arches/sky_bridge_007.png", 40, None),
    "gate_night": ("skylands/bridges_arches/sky_bridge_007.png", 40, None),
    "gate_cave_mouth": ("buildings/desert_ruin_entrance.png", 76, "dark"),
    "gate_cave_exit": ("buildings/desert_ruin_entrance.png", 76, "dark"),
    "gate_stairs_down": ("dungeons/doors_gates/doors_gates_008.png", 60, None),
    "gate_stairs_up": ("dungeons/doors_gates/doors_gates_008.png", 60, None),
    "gate_cave": ("buildings/desert_ruin_entrance.png", 44, "dark"),
    "gate_crypt": ("dungeons/doors_gates/doors_gates_008.png", 40, None),
}


def _tint(img: Image.Image, mode: str) -> Image.Image:
    arr = np.asarray(img).astype(np.float32)
    rgb = arr[..., :3]
    gray = rgb.mean(axis=2, keepdims=True)
    if mode == "iron":
        rgb = gray * 0.75 + rgb * 0.25
        rgb *= np.array([0.95, 0.98, 1.05])
    elif mode == "dark":
        rgb = rgb * np.array([0.78, 0.78, 0.86])
    elif mode == "night":
        rgb = rgb * np.array([0.5, 0.56, 0.86])
    elif mode == "dim":
        rgb = gray * 0.7 + rgb * 0.3
        rgb *= 0.8
    elif mode == "wood":
        hsv = np.asarray(Image.fromarray(arr[..., :3].astype(np.uint8)).convert("HSV")).astype(np.float32) / 255.0
        blue = (hsv[..., 0] > 0.5) & (hsv[..., 0] < 0.8)
        hsv[..., 0] = np.where(blue, 0.07, hsv[..., 0])
        hsv[..., 1] = np.where(blue, hsv[..., 1] * 0.7, hsv[..., 1])
        hsv[..., 2] = np.where(blue, hsv[..., 2] * 1.1, hsv[..., 2])
        rgb = np.asarray(Image.fromarray((np.clip(hsv, 0, 1) * 255).astype(np.uint8), "HSV").convert("RGB")).astype(np.float32)
    arr[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def fountain(width: float = 68) -> tuple[Image.Image, tuple[int, int]]:
    """Plaza fountain: a stone basin (pack stone texture) with rippling
    water and the pack's crystal pedestal in the middle, spraying water."""
    W_, H_ = int(width * K), int(width * K * 0.95)
    out = np.zeros((H_, W_, 4), np.float32)
    stone = pack.synthesize([(pack.crop("@2", (918, 330, 956, 374)), 1.0)], W_, H_, 3, patch=30, step=18)
    yy, xx = np.mgrid[0:H_, 0:W_].astype(np.float32)
    cx, cy = W_ / 2, H_ * 0.7
    rx, ry = W_ * 0.48, H_ * 0.26
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    wall = ((xx - cx) / rx) ** 2 + ((yy - cy - H_ * 0.06) / ry) ** 2
    rim = (d <= 1.0)
    body = (wall <= 1.0) & (yy > cy)
    out[body | rim, :3] = stone[body | rim] * 0.78
    out[body | rim, 3] = 1.0
    out[rim, :3] = stone[rim] * 1.05
    inner = ((xx - cx) / (rx * 0.82)) ** 2 + ((yy - cy) / (ry * 0.74)) ** 2
    water = inner <= 1.0
    depth = np.clip(1.0 - inner, 0, 1)
    wc = np.array([0.42, 0.78, 0.92]) * (1 - depth[..., None] * 0.5) + np.array([0.12, 0.38, 0.62]) * depth[..., None] * 0.5
    ripple = (np.sin(np.sqrt((xx - cx) ** 2 + ((yy - cy) * 2.2) ** 2) / 3.0) > 0.85)
    wc[ripple] = wc[ripple] * 0.7 + 0.3
    out[water, :3] = wc[water]
    out[(inner > 0.92) & water, :3] = 0.85
    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
    pillar = pack.content(pack.image("skylands/sky_ruins/sky_ruin_003.png"))
    pw = int(W_ * 0.34)
    pillar = pillar.resize((pw, int(pillar.height * pw / pillar.width)), Image.LANCZOS)
    img.alpha_composite(pillar, (int(cx - pw / 2), max(0, int(cy - pillar.height + ry * 0.2))))
    arr = np.asarray(img).copy()
    # Water arcs from the crystal into the basin.
    top_y = max(0, int(cy - pillar.height + ry * 0.2)) + 6
    for side in (-1, 1):
        for t in np.linspace(0, 1, 160):
            x = cx + side * (t * rx * 0.62)
            y = top_y + 10 - 40 * t + 92 * t * t
            for k in range(3):
                xi, yi = int(x) + k * side, int(y)
                if 0 <= yi < H_ and 0 <= xi < W_:
                    arr[yi, xi] = (196, 236, 255, 230)
    return Image.fromarray(arr), (W_ // 2, int(cy + ry + H_ * 0.06))


def fence_v(width: float = 9) -> tuple[Image.Image, tuple[int, int]]:
    """A fence running north–south: posts with two rails between them,
    cut from the new fence (stage 21)."""
    fence = pack.content(pack.image(NS % "hd/greenreach/village/wood_fence"))
    post = fence.crop((0, 0, int(fence.width * 0.19), fence.height))
    scale = width * K / post.width
    post = post.resize((max(1, int(post.width * scale)), max(1, int(post.height * scale))), Image.LANCZOS)
    h = 38 * K
    out = Image.new("RGBA", (post.width, h), (0, 0, 0, 0))
    arr = np.asarray(out).copy()
    mid = post.width // 2
    top, bottom = int(post.height * 0.45), h - int(post.height * 0.45)
    # Two rails seen from the side of the road: a light top edge, a dark underside.
    for x0 in (mid - 5, mid + 1):
        for k, col in enumerate(((112, 72, 42, 255), (196, 140, 82, 255), (172, 116, 64, 255), (112, 72, 42, 255))):
            arr[top:bottom, x0 + k] = col
    out = Image.fromarray(arr)
    out.alpha_composite(post, (0, 0))
    out.alpha_composite(post, (0, h - post.height))
    return out, (out.width // 2, h - 2)


def _roof(img: Image.Image, hue: float) -> Image.Image:
    """Re-tints red/orange roof tiles (upper part of the art) to another hue."""
    arr = np.asarray(img).copy()
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(np.float32)
    h, s, v = hsv[..., 0] / 255.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0
    rows = np.arange(arr.shape[0])[:, None] / arr.shape[0]
    roof = ((h < 0.09) | (h > 0.94)) & (s > 0.35) & (v > 0.25) & (rows < 0.62) & (arr[..., 3] > 0)
    nh = np.where(roof, hue, h)
    ns = np.where(roof, s * (0.55 if hue in (0.6, 0.58, 0.3, 0.33) else 0.85), s)
    nv = np.where(roof, v * 0.95, v)
    out = Image.fromarray((np.stack([nh, ns, nv], -1) * 255).astype(np.uint8), "HSV").convert("RGB")
    arr[..., :3] = np.asarray(out)
    return Image.fromarray(arr)


def make(rel: str, width: float, hue: float | None = None, tint: str | None = None) -> tuple[Image.Image, tuple[int, int]]:
    img = pack.content(pack.image(rel))
    if hue is not None:
        img = _roof(img, hue)
    if tint is not None:
        img = _tint(img, tint)
    scale = width * K / img.width
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    img = img.resize(size, Image.LANCZOS)
    # Feet: bottom-centre of the opaque mass (ignores a soft shadow skirt).
    a = np.asarray(img)[:, :, 3]
    rows = np.nonzero((a > 128).sum(axis=1) > img.width * 0.08)[0]
    bottom = int(rows.max()) if len(rows) else img.height - 1
    return img, (img.width // 2, bottom)


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = ROOT / "assets" / "art_manifest.json"
    art = json.loads(manifest_path.read_text())
    made = []

    def save(name: str, img: Image.Image, origin: tuple[int, int]) -> None:
        img.save(OUT / f"{name}.png", optimize=True)
        art[f"world_hd/{name}.png"] = {"size": [img.width, img.height], "origin": list(origin), "scale": 1.0 / K}
        made.append(name)

    for name, (rel, width, hue) in BUILDINGS.items():
        img, origin = make(rel, width, hue)
        save(name, img, origin)
    (OUT / "props").mkdir(exist_ok=True)
    for name, (rel, width, tint) in PROPS.items():
        img, origin = make(rel, width, tint=tint)
        save(f"props/{name}", img, origin)
    img, origin = fence_v()
    save("village_fence_v", img, origin)
    img, origin = fountain()
    save("village_fountain", img, origin)
    # Drifting clouds under the island (scripts/sky_clouds.gd).
    for index, name in enumerate(["medium_14", "medium_09", "medium_25"]):
        for mode, tint in (("day", None), ("night", "night")):
            img, origin = make(f"clouds/{name}.png", 96 - index * 14, tint=tint)
            save(f"cloud_puff_{mode}_{index}", img, (img.width // 2, img.height // 2))
    for style, cfg in STYLE.items():
        for index, (rel, width) in enumerate(cfg.get("trees", [])):
            img, origin = make(rel, width)
            save(f"{style}_tree_{index}", img, origin)
        for index, (rel, width) in enumerate(cfg.get("bushes", [])):
            img, origin = make(rel, width)
            save(f"{style}_bush_{index}", img, origin)
    manifest_path.write_text(json.dumps(dict(sorted(art.items())), indent=1) + "\n")
    print(f"  hd sprites: {len(made)}")


if __name__ == "__main__":
    build()
