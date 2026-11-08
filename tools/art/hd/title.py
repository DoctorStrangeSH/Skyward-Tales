"""Title screen islands from the asset pack: a big floating island with a
little village and trees on top, two small islets. Saved at 2x
(assets/ui/title_*_hd.png); the title screen draws them at half scale."""
from __future__ import annotations

from PIL import Image

from hd import pack

ROOT = pack.ROOT
FI = "skylands/floating_islands/floating_island_%03d.png"


def _scaled(rel: str, width: int) -> Image.Image:
    img = pack.content(pack.image(rel))
    return img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)


def build() -> None:
    big = _scaled(FI % 1, 760)
    # Things standing on the top surface, back to front: (rel, width, x, y_feet).
    on_top = [
        ("nature/summer_oak.png", 120, 120, 120),
        ("nature/spring_blossom_tree.png", 110, 600, 105),
        ("buildings/stone_cathedral.png", 150, 300, 118),
        ("buildings/cottage_red_roof.png", 120, 470, 138),
        ("nature/fruit_tree.png", 100, 640, 160),
        ("buildings/windmill_house.png", 110, 175, 175),
        ("buildings/tavern_red_roof.png", 150, 390, 196),
        ("nature/summer_oak.png", 96, 560, 205),
    ]
    for rel, width, x, y in sorted(on_top, key=lambda t: t[3]):
        sprite = _scaled(rel, width)
        big.alpha_composite(sprite, (int(x - sprite.width / 2), int(y - sprite.height)))
    big.save(ROOT / "assets" / "ui" / "title_island_hd.png", optimize=True)
    _scaled(FI % 2, 230).save(ROOT / "assets" / "ui" / "title_islet_0_hd.png", optimize=True)
    _scaled(FI % 3, 160).save(ROOT / "assets" / "ui" / "title_islet_1_hd.png", optimize=True)
    print("  title islands")


if __name__ == "__main__":
    build()
