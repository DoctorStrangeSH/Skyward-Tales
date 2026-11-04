#!/usr/bin/env python3
"""Validate committed 8-direction PNG atlases without external packages."""
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
# (path, cell size): every directional sheet is 4 columns x 8 rows.
SHEETS = {
    "hero": (ROOT / "assets/sprites/characters/hero_8dir_walk.png", 32),
    "hero_f": (ROOT / "assets/sprites/characters/hero_f_8dir_walk.png", 32),
    "slime": (ROOT / "assets/sprites/enemies/forest_slime_true8.png", 32),
    "wolf": (ROOT / "assets/sprites/enemies/forest_wolf_8dir.png", 32),
    "shaman": (ROOT / "assets/sprites/enemies/forest_shaman_8dir.png", 32),
    "guardian": (ROOT / "assets/sprites/enemies/grove_guardian_8dir.png", 48),
    "bat": (ROOT / "assets/sprites/enemies/cave_bat_8dir.png", 32),
    "echo": (ROOT / "assets/sprites/enemies/echo_warden_8dir.png", 48),
    "sentinel": (ROOT / "assets/sprites/enemies/sky_sentinel_8dir.png", 32),
    "wisp": (ROOT / "assets/sprites/enemies/wind_wisp_8dir.png", 32),
    "tempest": (ROOT / "assets/sprites/enemies/tempest_colossus_8dir.png", 48),
    "fireball": (ROOT / "assets/sprites/magic/fireball_8dir.png", 32),
    "frostbolt": (ROOT / "assets/sprites/magic/frostbolt_8dir.png", 32),
    "chain_lightning": (ROOT / "assets/sprites/magic/chain_lightning_8dir.png", 32),
}
for npc in sorted((ROOT / "assets/sprites/npcs").glob("*.png")):
    SHEETS["npc_" + npc.stem] = (npc, 32)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

def verify_png(filename, cell):
    expected = (cell * 4, cell * 8)
    data = filename.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{filename} is not a PNG")
    if len(data) < 33 or data[12:16] != b"IHDR":
        raise ValueError(f"{filename} lacks PNG IHDR")
    width, height, depth, mode = struct.unpack(">IIBB", data[16:26])
    if (width, height) != expected or depth != 8 or mode != 6:
        raise ValueError(f"{filename}: expected RGBA {expected[0]}x{expected[1]} 8bit, got {(width,height,depth,mode)}")
    # Reject truncated PNG or stray data after IEND; actual anatomical views need visual QA.
    if data[-12:] != b"\x00\x00\x00\x00IEND\xaeB\x60\x82":
        raise ValueError(f"{filename}: missing PNG terminator")
    print(f"OK: {filename.relative_to(ROOT)} ({expected[0]}x{expected[1]} RGBA, 4x8 frames)")
    
def main():
    for filename, cell in SHEETS.values():
        if not filename.is_file():
            raise FileNotFoundError(filename)
        verify_png(filename, cell)
    print("NOTE: Back-facing anatomy requires visual inspection; dimensions alone cannot prove this.")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, FileNotFoundError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
