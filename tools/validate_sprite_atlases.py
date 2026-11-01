#!/usr/bin/env python3
"""Validate the directional sprite PNGs inside assets/sprites/sprite_sheets.zip.

Uses only Python's standard library; checks archive members and PNG IHDR dimensions.
Expected atlas size: 4 columns × 8 rows × 32 pixels = 128 × 256.
"""
from pathlib import Path
import struct
import sys
import zipfile

ARCHIVE = Path("assets/sprites/sprite_sheets.zip")
EXPECTED = {
    "hero_8dir_walk.png": (128, 256),
    "forest_slime_8dir.png": (128, 256),
    "fireball_8dir.png": (128, 256),
}

def png_dimensions(data: bytes) -> tuple[int, int]:
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("not a PNG with an IHDR header")
    return struct.unpack(">II", data[16:24])

def main() -> int:
    if not ARCHIVE.is_file():
        print(f"Missing sprite archive: {ARCHIVE}", file=sys.stderr)
        return 1
    with zipfile.ZipFile(ARCHIVE) as archive:
        names = set(archive.namelist())
        missing = set(EXPECTED) - names
        if missing:
            print("Missing archive entries: " + ", ".join(sorted(missing)), file=sys.stderr)
            return 1
        for name, expected in EXPECTED.items():
            actual = png_dimensions(archive.read(name))
            if actual != expected:
                print(f"{name}: expected {expected}, got {actual}", file=sys.stderr)
                return 1
            print(f"OK {name}: {actual[0]}×{actual[1]}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
