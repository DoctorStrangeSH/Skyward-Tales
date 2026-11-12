"""Icons for the rewards of peaceful trades (Этап 22): trail rations from
fishing and gear fittings from the mine. 16×16, like the other bag icons.
Run: python3 tools/art/reward_icons.py"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "icons"
O = (38, 26, 30, 255)


def draw(name, rows, palette):
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                image.putpixel((x, y), palette[ch])
    image.save(OUT / f"{name}.png")


PARCEL = [
    "................",
    "......ooo.......",
    ".....oSSSo......",
    "....ooSsSoo.....",
    "...oCCsSsCCo....",
    "..oCcCCsCCcCo...",
    "..oCCCCsCCCCo...",
    ".oCCcCCsCCCcCo..",
    ".osssssSsssssoo.",
    ".oCCCCCsCCCCoFFo",
    ".oCcCCCsCCcoFfFo",
    ".oCCCCCsCCCoFFo.",
    "..oCCcCsCCCCoo..",
    "..oDDDDsDDDDo...",
    "...oooooooooo...",
    "................",
]
draw("trail_ration", PARCEL, {"o": O, "C": (196, 160, 108, 255), "c": (224, 194, 142, 255), "D": (150, 116, 76, 255),
    "S": (150, 96, 60, 255), "s": (118, 72, 46, 255), "F": (120, 170, 200, 255), "f": (190, 226, 240, 255)})
draw("captain_ration", PARCEL, {"o": O, "C": (70, 110, 170, 255), "c": (110, 156, 210, 255), "D": (48, 78, 130, 255),
    "S": (240, 200, 90, 255), "s": (200, 150, 50, 255), "F": (240, 180, 70, 255), "f": (255, 232, 150, 255)})

INSET = [
    "................",
    ".....oooooo.....",
    "...ooKKKKKKoo...",
    "..oKKkooookKKo..",
    "..oKkoPPPPokKo..",
    ".oKkoPpPPPPokKo.",
    ".oKoPpwPPPPDoKo.",
    ".oKoPpPPPPDDoKo.",
    ".oKoPPPPPDDDoKo.",
    ".oKoPPPPDDDDoKo.",
    ".oKkoPDDDDDokKo.",
    "..oKkoDDDDokKo..",
    "..oKKkooookKKo..",
    "...ooKKKKKKoo...",
    ".....oooooo.....",
    "................",
]
draw("amethyst_inset", INSET, {"o": O, "K": (200, 120, 70, 255), "k": (240, 170, 110, 255), "P": (170, 110, 220, 255),
    "p": (214, 170, 250, 255), "w": (250, 240, 255, 255), "D": (110, 66, 160, 255)})

EDGE = [
    "................",
    "...........oo...",
    "..........owPo..",
    ".........owpPo..",
    "........owpPDo..",
    ".......owpPPDo..",
    "......owpPPDo...",
    ".....owpPPDDo...",
    "....owpPPDDo....",
    "...owpPPDDo.....",
    "..ogGpPDDo......",
    "..oGgGDDo.......",
    ".oGGgGoo........",
    ".ogGGo..........",
    "..ooo...........",
    "................",
]
draw("facet_edge", EDGE, {"o": O, "w": (250, 240, 255, 255), "p": (214, 170, 250, 255), "P": (170, 110, 220, 255),
    "D": (110, 66, 160, 255), "G": (120, 124, 140, 255), "g": (170, 176, 190, 255)})

RIVETS = [
    "................",
    "................",
    "....ooo.........",
    "...okKKo........",
    "..okwKKDo..ooo..",
    "..oKKKDDo.okKKo.",
    "..oKKDDDookwKKDo",
    "...oDDDo.oKKKDDo",
    "....ooo..oKKDDDo",
    "..........oDDDo.",
    "....ooo....ooo..",
    "...okKKo........",
    "..okwKKDo.......",
    "..oKKKDDo.......",
    "...oDDDo........",
    "....ooo.........",
]
draw("copper_rivets", RIVETS, {"o": O, "K": (210, 126, 72, 255), "k": (244, 176, 116, 255), "w": (255, 226, 190, 255), "D": (150, 80, 46, 255)})
