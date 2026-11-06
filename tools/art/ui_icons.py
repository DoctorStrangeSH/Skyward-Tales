"""Small pixel icons for the action bar menu buttons (assets/ui/menu_*.png).

Each icon is a 12x12 character grid; letters map to the palette below.
Run: python3 tools/art/ui_icons.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "ui"
PAL = {
    "k": (28, 18, 14), "w": (250, 236, 200), "g": (255, 206, 92), "G": (196, 132, 40),
    "b": (122, 82, 52), "B": (84, 54, 34), "r": (200, 64, 56), "R": (130, 36, 36),
    "s": (176, 186, 200), "S": (110, 120, 138), "p": (226, 200, 150), "P": (170, 140, 96),
    "l": (110, 190, 255), "L": (60, 110, 190), "e": (120, 200, 110), "E": (60, 120, 60),
}
ICONS = {
    "hero": [
        "....kkkk....",
        "...kssssk...",
        "..kssSSssk..",
        "..ksSkkSsk..",
        "..kspppSsk..",
        "...kpppk....",
        "..kkLLLkk...",
        ".kLlLLLlLk..",
        ".kLlLgLlLk..",
        ".kLLLLLLLk..",
        "..kBk.kBk...",
        "..kkk.kkk...",
    ],
    "journal": [
        "............",
        ".kkkkkkkkk..",
        ".kRrrrrrrRk.",
        ".kRrgggrrRk.",
        ".kRrrrrrrRk.",
        ".kRrgggrrRk.",
        ".kRrrrrrrRk.",
        ".kRrrrrrrRk.",
        ".kRrrrrrrRk.",
        ".kwwwwwwwwk.",
        ".kkkkkkkkkk.",
        "............",
    ],
    "map": [
        "............",
        ".kkk.kkk.kk.",
        "kpPpkpPpkpPk",
        "kppPkpppkPpk",
        "kpprkpPpkppk",
        "kpPrrppPkppk",
        "kppPkrrpkPpk",
        "kPppkppgkppk",
        "kppPkpPpkpPk",
        ".kkk.kkk.kk.",
        "............",
        "............",
    ],
    "talents": [
        ".....kk.....",
        "....kggk....",
        "....kggk....",
        "kkkkgggGkkkk",
        "kgggggggggGk",
        ".kGggggggGk.",
        "..kGgggggk..",
        "..kggGGggk..",
        ".kggk..kggk.",
        ".kgk....kgk.",
        ".kk......kk.",
        "............",
    ],
    "craft": [
        "............",
        "..kkkkkkk...",
        ".ksssssssk..",
        ".kSsssssSk..",
        ".kSSSSSSSk..",
        "..kkkbkkk...",
        "....kbk.....",
        "....kbk.....",
        "....kBk.....",
        "....kbk.....",
        "....kBk.....",
        "....kkk.....",
    ],
    "bag": [
        "............",
        "....kkkk....",
        "...kb..bk...",
        "..kkkkkkkk..",
        ".kbbbbbbbbk.",
        ".kbBbbbbBbk.",
        ".kbbbggbbbk.",
        ".kbbbggbbbk.",
        ".kbbbbbbbbk.",
        ".kBbbbbbbBk.",
        "..kkkkkkkk..",
        "............",
    ],
    "bestiary": [
        "............",
        "...kkkkkk...",
        "..kwwwwwwk..",
        ".kwwwwwwwwk.",
        ".kwkkwwkkwk.",
        ".kwkkwwkkwk.",
        ".kwwwkkwwwk.",
        "..kwwwwwwk..",
        "...kwkwkwk..",
        "...kkkkkk...",
        "............",
        "............",
    ],
}

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, rows in ICONS.items():
        img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row.ljust(12, ".")):
                if ch in PAL:
                    img.putpixel((x, y), PAL[ch] + (255,))
        img.save(OUT / f"menu_{name}.png")
    print("ui icons:", ", ".join(ICONS))

if __name__ == "__main__":
    main()
