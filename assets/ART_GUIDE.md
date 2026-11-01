# Skyward Tales — Art Guide

## Visual target
Use polished, readable fantasy pixel art with warm highlights, rich but controlled palettes, clear silhouettes, and transparent backgrounds. Avoid primitive placeholder shapes for characters, enemies, magic, and interactive props once an authored sprite exists.

## Runtime rules
- Use raster PNG sprite sheets, not SVG.
- Use nearest-neighbour texture filtering (`CanvasItem.TEXTURE_FILTER_NEAREST`).
- Avoid bilinear filtering, mipmaps, and fractional pixel positioning.
- Keep source art and processed atlases in version control.
- Current directional sheets use 8 rows and 4 columns.

## Direction row order
1. Down
2. Down-right
3. Right
4. Up-right
5. Up
6. Up-left
7. Left
8. Down-left

Frames are read left-to-right within each direction row. This order is shared by `DirectionalSprite` and all directional sheets.

## Current sheets
The PNG files are packed into `assets/sprites/sprite_sheets.zip` and extracted at startup to `user://SkywardTales/sprites/` by `scripts/sprite_archive.gd`.

- `hero_8dir_walk.png` — 32×32 cells, 4 frames × 8 directions.
- `forest_slime_8dir.png` — 32×32 cells, 4 poses × 8 directions; the round slime poses are rotated to face movement.
- `fireball_8dir.png` — 32×32 cells, 4 flight frames × 8 directions.

See `assets/sprites/asset_manifest.json` for machine-readable layout metadata.
