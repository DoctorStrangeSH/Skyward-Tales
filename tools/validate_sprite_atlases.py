#!/usr/bin/env python3
"""Validate committed 8-direction PNG atlases without external packages."""
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEETS = {
    "hero": ROOT / "assets/sprites/characters/hero_8dir_walk.png",
    "slime": ROOT / "assets/sprites/enemies/forest_slime_true8.png",
    "fireball": ROOT / "assets/sprites/magic/fireball_8dir.png",
}
EXPECTED_SIZE = (128, 256)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

def verify_png(filename):
    data = filename.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{filename} is not a PNG")
    if len(data) < 33 or data[12:16] != b"IHDR":
        raise ValueError(f"{filename} lacks PNG IHDR")
    width, height, depth, mode = struct.unpack(">IIBB", data[16:26])
    if (width, height) != EXPECTED_SIZE or depth != 8 or mode != 6:
        raise ValueError(f"{filename}: expected RGBA 128x256 8bit, got {(width,height,depth,mode)}")
    # Reject truncated PNG or stray data after IEND; actual anatomical views need visual QA.
    if data[-12:] != b"\x00\x00\x00\x00IEND\xaeB\x60\x82":
        raise ValueError(f"{filename}: missing PNG terminator")
    print(f"OK: {filename.relative_to(ROOT)} (128x256 RGBA, 4x8 frames)")
    
def main():
    for filename in SHEETS.values():
        if not filename.is_file():
            raise FileNotFoundError(filename)
        verify_png(filename)
    print("NOTE: Back-facing anatomy requires visual inspection; dimensions alone cannot prove this.")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, FileNotFoundError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
