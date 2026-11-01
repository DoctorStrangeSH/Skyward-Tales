# Skyward Tales

**Skyward Tales** is a 2D pixel-art open-world fantasy RPG built with Godot 4.

The project is being developed as a long-lived, data-driven game: exploration, combat, magic, quests, NPCs, items, progression and world content should be extendable without rewriting core systems.

## Current project status

The repository was empty at the start of development. The first implementation milestone establishes the Godot project, its architecture, a playable exploration/combat/quest vertical slice, and the documentation needed for future contributors.

## Design pillars

- A handcrafted-feeling world with distinct biomes, settlements, ruins, caves and secrets.
- Responsive top-down action combat and meaningful magical build choices.
- Character progression through levels, attributes, abilities, equipment and discoveries.
- A story-driven main quest supported by memorable side quests and world events.
- NPCs, factions and choices that make locations feel inhabited.
- Modular, data-driven content so new spells, quests, enemies and items are inexpensive to add.

## Technology

- Godot 4.x
- GDScript
- 2D top-down presentation
- Pixel-art-first rendering (nearest-neighbour filtering and integer-scaled viewport)

## Getting started

1. Install a current stable Godot 4 release.
2. Import `project.godot` in the Godot Project Manager.
3. Run the project (F6/F5 or the Play button).

See [docs/ROADMAP.md](docs/ROADMAP.md) for milestones and [docs/AI_HANDOFF.md](docs/AI_HANDOFF.md) for the technical overview and continuation instructions.

## Controls

- WASD / Arrow keys — move
- E — interact / collect
- Left mouse button — cast the equipped spell
- Esc — pause; E — close dialogue

## Development principles

- Keep systems small, cohesive and documented.
- Prefer resources/data files for content definitions over hard-coded content.
- Keep player-facing text in Russian for the first playable build; localization infrastructure should make additional languages possible.
- Every milestone should leave the project runnable.
- Update the roadmap and AI handoff whenever architecture, controls or project status changes.
