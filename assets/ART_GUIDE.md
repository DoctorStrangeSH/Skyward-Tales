# Skyward Tales — Art Guide

## Visual target

Cosy, readable fantasy pixel art in the spirit of modern 16-bit-inspired RPGs:
warm sunlit greens by day, cool teal/violet moonlight at night, tinted
outlines (never pure black), light from the top-left, soft blue-purple
shadows, chibi characters (~26 px tall) and 3/4 top-down scenery.
All art is original.

## How the art is made

Everything under `assets/world`, `assets/props` and `assets/sprites` is generated
by code — no hand-edited PNGs:

```bash
python3 tools/art/build.py              # everything
python3 tools/art/build.py --only world # or: characters | props
```

Requires Python 3 with Pillow, numpy and scipy. Output is deterministic.
`assets/art_manifest.json` records every sprite's size and anchor ("origin").

| Module | What it draws |
| --- | --- |
| `tools/art/palettes.py` | Day and night colour ramps |
| `tools/art/terrain.py` | Region ground: grass, trails (from `data/regions.json`), ponds, flowers |
| `tools/art/flora.py` | Trees, bushes, the foliage border around each map |
| `tools/art/props.py` | Ruins, standing stones, chests, herbs, ore, crates, potions, gates |
| `tools/art/characters.py` | Chibi humanoid rig: hero, NPCs, forest shaman |
| `tools/art/creatures.py` | Slime, wolf, grove guardian (48 px), spell projectiles |

To change a character, edit its `Look` in `characters.py` (colours, hair
style, hat, robe, staff…) and rebuild. To move scenery, edit the `terrain`
section of `data/regions.json` and rebuild: collisions and art read the same data.

## Runtime rules

- Nearest-neighbour filtering, no mipmaps, 1 world pixel = 1 viewport pixel.
- `Main` and `World` are y-sorted: actors walk behind trees and ruins.
- Ground is drawn at z −100, the foliage border at z 60 (above actors).
- Directional sheets: 4 frames × 8 rows. Row order: down, down-right, right,
  up-right, up, up-left, left, down-left. Left-facing rows mirror right-facing
  ones. Back views (`up`, `up_right`) never show a face.
- Cell size is 32×32 (guardian 48×48); feet sit at y=30 (guardian y=43).

## Sheets

| File | Cell | Notes |
| --- | --- | --- |
| `sprites/characters/hero_8dir_walk.png` | 32 | Walk cycle |
| `sprites/npcs/<npc_id>.png` | 32 | Idle breathing (NPC ids from `data/regions.json`) |
| `sprites/enemies/forest_slime_true8.png` | 32 | Squash-and-stretch hop |
| `sprites/enemies/forest_wolf_8dir.png` | 32 | Trot |
| `sprites/enemies/forest_shaman_8dir.png` | 32 | Robed walk |
| `sprites/enemies/grove_guardian_8dir.png` | 48 | Boss walk |
| `sprites/magic/{fireball,frostbolt,chain_lightning}_8dir.png` | 32 | Flight |

## Next steps for art

- Attack / hurt / cast animations (currently feedback is a colour flash).
- Water shimmer and swaying grass via shaders.
- Item icons for the inventory.
- A pixel font for the interface.
