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
Hero and fireball PNGs are expected inside `assets/sprites/sprite_sheets.zip` and extracted at startup to `user://SkywardTales/sprites/` by `scripts/sprite_archive.gd`.

- `hero_8dir_walk.png` — 32×32 cells, 4 frames × 8 directions.
- `assets/sprites/enemies/forest_slime_true8.png` — настоящий атлас PNG 32×32 × (4 кадра × 8 направлений), включая **вид сзади без лица**; подключён напрямую как `res://`.
- Старый `forest_slime_8dir.png` в архиве — устаревшая версия, не использовать для новых врагов.
- `fireball_8dir.png` — 32×32 cells, 4 flight frames × 8 directions.

See `assets/sprites/asset_manifest.json` for machine-readable layout metadata.

## Runtime PNG paths and true eight views

The runtime no longer requires ZIP extraction: hero, slime, fireball are committed as standalone PNGs. Paths:

- `res://assets/sprites/characters/hero_8dir_walk.png`
- `res://assets/sprites/enemies/forest_slime_true8.png`
- `res://assets/sprites/magic/fireball_8dir.png`

All 8 rows MUST represent actual orientations for characters and enemies: down, down-right, right, up-right, up, up-left, left, down-left. Rear `up` shows a true back with no eyes, mouth, or other frontal facial features; rear diagonal rows show the rear three-quarter anatomy. Do not rotate front-facing art to fake back views. All PNG atlases: 128x256 px, 32x32 px cells, 4 columns x 8 rows, RGBA. Current art is an initial playable pixel-art pass and needs further visual polish against approved concept art.

## REJECTED ART — user review, 2026-11-01

All current placeholder PNG visuals (hero, slime, fireball) are **REJECTED** by the user for visual quality. Do not use them as a visual-quality benchmark and do not mark art milestone complete. Keep them only as temporary runtime assets until they are replaced with approved, carefully pixel-edited, richly detailed, transparent RGBA sheets. Prioritize matching the user's previously approved fantasy reference, high-quality silhouettes, lighting, sprite consistency and accurate true back/side directional anatomy. Validate in-game at the actual camera scale before accepting new art.
