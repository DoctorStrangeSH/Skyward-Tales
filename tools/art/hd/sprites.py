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

# name: (pack file, world width, roof hue (None = keep), origin y-fraction from the bottom of content)
BUILDINGS = {
    "village_house_small": (B % "cottage_red_roof", 74, None),
    "village_house_wine": (B % "cottage_red_roof", 78, 0.97),
    "village_house_blue": (B % "buildings_extra_002", 70, 0.6),
    "village_house_slate": (B % "buildings_extra_002", 82, 0.58),
    "village_house_moss": (B % "cottage_red_roof", 88, 0.3),
    "village_house_large": (B % "buildings_extra_004", 104, None),
    "village_house_long": (B % "buildings_extra_002", 112, None),
    "village_hall": (B % "buildings_extra_001", 124, None),
    "village_tavern_1": (B % "tavern_red_roof", 104, None),
    "village_tavern_2": (B % "tavern_red_roof", 114, None),
    "village_library_1": (B % "arcane_shop", 90, None),
    "village_library_2": (B % "buildings_extra_003", 96, None),
    "village_guild_1": (W % "buildings/buildings_005", 104, None),
    "village_guild_2": (B % "stone_cathedral", 106, None),
    "village_home_1": (B % "cottage_red_roof", 80, 0.08),
    "village_home_2": (B % "buildings_extra_002", 94, 0.08),
    "village_windmill": (B % "windmill_house", 84, None),
    "village_arch": (B % "flower_arch_gate", 64, None),
    "village_market_red": (B % "market_stall", 60, None),
    "village_market_green": (B % "buildings_extra_018", 60, 0.33),
    "decor_stall_white": (W % "resources_market/resources_market_001", 66, None),
    "decor_stall_blue": (B % "buildings_extra_018", 64, 0.6),
    "decor_stall_orange": (B % "market_stall", 64, 0.08),
    "decor_wagon": (B % "buildings_extra_009", 56, None),
    "decor_forge": (W % "buildings/buildings_001", 64, None),
    "village_well": (P % "prop_026", 38, None),
    "village_lamp": (S % "bridges_arches/sky_bridge_008", 18, None),
    "village_sign": (P % "prop_022", 22, None),
    "village_board": (W % "resources_market/resources_market_019", 34, None),
    "village_fence_h": (P % "prop_030", 36, None),
    "village_hay": (W % "resources_market/resources_market_036", 26, None),
    "decor_potted_plant": (W % "resources_market/resources_market_009", 14, None),
    "ruins": (S % "sky_ruins/sky_ruin_006", 104, None),
    "mine_entrance": (P % "props_extra_010", 72, None),
    "village_flowers_a": (N2 % "nature_025", 30, None),
    "village_flowers_b": (N2 % "nature_extra_023", 28, None),
    "village_flowers_c": (N2 % "nature_extra_036", 28, None),
    "decor_armor_stand": (W % "forges_tools/forges_tools_012", 16, None),
    "decor_weapon_rack": (W % "forges_tools/forges_tools_008", 26, None),
    "decor_workbench": (W % "tailor_wood_mason/tailor_wood_mason_013", 32, None),
    "village_bench": (W % "tailor_wood_mason/tailor_wood_mason_018", 26, None),
    "gather_wood": (W % "tailor_wood_mason/tailor_wood_mason_020", 28, None),
    "gather_stone": ("nature/nature_extra_046.png", 28, None),
    "gather_iron": ("crystals/crystal_ores/crystal_ore_027.png", 28, None),
    "gather_healroot": ("nature/nature_extra_029.png", 18, None),
    "gather_bluebell": ("crystals/arcane_flora/arcane_flora_025.png", 18, None),
}


C = "crystals/%s.png"
D = "dungeons/%s.png"
R = "workshops/resources_market/resources_market_%03d.png"
# Gameplay props (props/<name>.png in the game): pack file, world width, tint.
PROPS = {
    "chest_gold_closed": (D % "chests_sarcophagi/chests_sarcophagi_002", 28, None),
    "chest_gold_open": (D % "chests_sarcophagi/chests_sarcophagi_001", 28, None),
    "chest_iron_closed": (D % "chests_sarcophagi/chests_sarcophagi_002", 28, "iron"),
    "chest_iron_open": (D % "chests_sarcophagi/chests_sarcophagi_001", 28, "iron"),
    "chest_wood_closed": (D % "chests_sarcophagi/chests_sarcophagi_002", 26, "wood"),
    "chest_wood_open": (D % "chests_sarcophagi/chests_sarcophagi_001", 26, "wood"),
    "chest_closed": (D % "chests_sarcophagi/chests_sarcophagi_002", 24, "wood"),
    "chest_open": (D % "chests_sarcophagi/chests_sarcophagi_001", 24, "wood"),
    "waystone_on": (C % "shrines_obelisks/crystal_shrine_001", 26, None),
    "waystone_off": (C % "shrines_obelisks/crystal_shrine_001", 26, "dim"),
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
    "supply_crate": (R % 14, 24, None),
    "coal_sack": (R % 39, 18, None),
    "flour_sack": (R % 44, 16, None),
    "map_fragment": (R % 27, 18, None),
    "lost_letter": (R % 28, 15, None),
    "song_scroll": (R % 20, 14, None),
    "loot_coins": (R % 22, 14, None),
    "pouch": (R % 3, 13, None),
    "lever_off": (D % "chests_sarcophagi/chests_sarcophagi_013", 22, None),
    "lever_on": (D % "chests_sarcophagi/chests_sarcophagi_012", 22, None),
    "gate_bridge_h": ("skylands/bridges_arches/sky_bridge_005.png", 44, None),
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


def fence_v(width: float = 8) -> tuple[Image.Image, tuple[int, int]]:
    """A fence running north–south: two posts and rails seen from above."""
    fence = pack.content(pack.image(P % "prop_030"))
    post = fence.crop((0, 0, int(fence.width * 0.22), fence.height))
    scale = width * K / post.width
    post = post.resize((int(post.width * scale), int(post.height * scale)), Image.LANCZOS)
    h = 36 * K
    out = Image.new("RGBA", (post.width, h), (0, 0, 0, 0))
    rail = np.asarray(post.crop((post.width // 3, post.height // 3, post.width // 3 + 2, post.height // 3 + 2)).resize((1, 1))).reshape(4)
    arr = np.asarray(out).copy()
    for x in (post.width // 2 - 3, post.width // 2 + 2):
        arr[post.height // 3: h - post.height // 2, x:x + 2] = rail
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
