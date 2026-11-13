"""Equipment icons from the asset pack: weapons, armour, jewellery and
relics, 32x32 (drawn in 16-unit UI cells, so they are crisp at 2x).

Run: python3 tools/art/hd/item_icons.py  (writes assets/icons/<id>.png)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from hd import pack  # noqa: E402

SW = "weapons/swords/swords_%02d.png"
ST = "weapons/staves_wands/staves_wands_%02d.png"
AX = "weapons/axes_hammers/axes_hammers_%02d.png"
BW = "weapons/bows/bows_%02d.png"
CH = "armor/chest/chest_%02d.png"
CL = "armor/cloaks/cloaks_%02d.png"
JW = "armor/jewelry_shields/jewelry_shields_%02d.png"
SH = "crystals/shrines_obelisks/crystal_shrine_%03d.png"
OR = "crystals/crystal_ores/crystal_ore_%03d.png"

ICONS = {
    # Blades.
    "traveler_sword": SW % 12, "iron_sword": SW % 8, "steel_sword": SW % 9, "skysteel_blade": SW % 5,
    "obsidian_blade": SW % 6, "skyfire_blade": SW % 7, "skyclaw_blade": SW % 16,
    "scout_knife": SW % 13, "shadow_dagger": SW % 15, "viper_fang": SW % 14,
    "guard_spear": ST % 4, "coral_pike": ST % 5, "storm_spear": ST % 6,
    "smith_hammer": AX % 10, "mountain_maul": AX % 11, "titan_breaker": AX % 3,
    # Staves and bows.
    "apprentice_staff": ST % 10, "ironbound_staff": ST % 27, "steel_staff": ST % 28, "skysteel_staff": ST % 18,
    "jelly_staff": AX % 16, "keeper_staff": ST % 19,
    "hunting_bow": BW % 7, "elm_longbow": BW % 1, "wind_bow": BW % 6, "blossom_bow": BW % 2,
    # Armour.
    "leather_armor": CH % 7, "wolfskin_mantle": CL % 8, "reinforced_wolf_mantle": CL % 4, "shell_mail": CH % 5,
    "steel_mail": CH % 6, "skysteel_mail": CH % 2, "ash_cloak": CL % 2, "crab_aegis": JW % 5,
    "ranger_jerkin": CH % 4, "warden_plate": CH % 3, "keeper_robe": CH % 1,
    # Jewellery and relics.
    "mana_amulet": JW % 6, "crystal_lens": JW % 7, "toad_crown": JW % 10, "spark_collar": JW % 11,
    "sky_thread": JW % 12, "earth_star": JW % 9, "keeper_sigil": JW % 3, "phoenix_feather": JW % 8,
    "pyromancer_core": SH % 19, "frost_heart": SH % 20, "storm_eye": SH % 18, "flame_heart": SH % 14,
    "golem_heart": OR % 26, "keeper_hourglass": SH % 11, "dusk_fang": SH % 16, "cog_charm": SH % 12,
    # Boss trophies (scripts/signature_gear.gd).
    "crypt_lantern": SH % 2, "heartwood_bark": CL % 1, "crab_king_shell": JW % 4, "echo_prism": JW % 1,
    "bog_signet": JW % 2, "giant_fist": AX % 1, "tempest_eye": SH % 3, "vail_cloak": CL % 3,
    "ash_brand": SW % 1, "titan_core": CH % 3, "pattern_tuner": ST % 20, "shade_shard": SH % 4,
}
## Trophies that share a picture with another item get their own colour.
TINTS = {"titan_core": (1.0, 0.55, 0.3)}
SIZE = 32


def icon(rel: str) -> Image.Image:
    img = pack.content(pack.image(rel))
    scale = (SIZE - 2) / max(img.width, img.height)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(img, ((SIZE - img.width) // 2, (SIZE - img.height) // 2))
    return out


def build() -> None:
    folder = pack.ROOT / "assets" / "icons"
    for item_id, rel in ICONS.items():
        img = icon(rel)
        if item_id in TINTS:
            r, g, b = TINTS[item_id]
            ch = img.split()
            img = Image.merge("RGBA", (ch[0].point(lambda v: min(255, int(v * r + 40 * r))), ch[1].point(lambda v: int(v * g)), ch[2].point(lambda v: int(v * b)), ch[3]))
        img.save(folder / f"{item_id}.png", optimize=True)
    print(f"  item icons: {len(ICONS)}")


if __name__ == "__main__":
    build()
