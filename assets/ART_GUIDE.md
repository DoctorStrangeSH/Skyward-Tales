# Skyward Tales — Art Guide

## One approved style

The owner's floating forest-island reference is the fixed master: detailed
three-quarter top-down fantasy pixel art, rich foliage, mossy grey/violet
stone, restrained daylight and warm windows. The look is slightly more
subdued than the reference, with dark graphite/plum UI and aged gold.
Do not generate alternative styles or several options unless requested.

Current direction: [ART_DIRECTION](../docs/ART_DIRECTION.md).
Godot editing: [ISLAND01_EDITING](../docs/ISLAND01_EDITING.md).

## Sources and reproducible builds

Approved original PNGs are retained in assets/New Sprites archives.
Do not replace detailed approved art with primitive placeholders.

The first island is rebuilt with:

    python3 tools/art/island01_polish.py

Pinned dependencies: Pillow 11.3.0, numpy 2.2.6, scipy 1.15.3.
This rebuild uses the tracked approved archive, existing cloud art and region
geometry. It needs no untracked assets/incoming pack. It writes the Greenreach
ground, clean southern sky, minimap, four oak variants, bank stones and an input/output checksum manifest. Decorative trees form a lakeside clearing; pond banks have stones, ferns and restrained ripples.

The broader legacy HD generator still requires its original local incoming
pack. Do not confuse that older requirement with the self-contained first-island
rebuild. Generated art changes must include the recipe and resulting assets.

## Runtime and scenes

- Base viewport 640×360. HD world textures use two texture pixels per world
  pixel and are displayed at half scale. Preserve source detail and anchors.
- World scenery and actors are y-sorted. Ground is at z -100.
- Final screen grading samples with Nearest and stays on CanvasLayer 1;
  HUD is on layer 2, preserving text and status-bar readability.
- Greenreach's southern sky has no baked waterfalls. CliffRim owns cliffs;
  scenes/regions/greenreach_waterfalls.tscn owns its editable water.
- scenes/props/island_waterfall.tscn is tool-enabled. Keep texture grain at
  world scale when resizing. Animation pauses with gameplay.
- Directional actors require eight actual views, including proper backs.
  Do not rotate a flat front-facing drawing into eight directions.

## Review

Rebuild, import, run relevant checks and capture the actual game at 1920×1080.
Use the same camera and time of day when comparing. Do not label a mockup as
an in-game capture. Keep one current style, rather than accumulating alternatives.
