# Directional sprite sheets

The game expects one ZIP archive at this exact path:

`assets/sprites/sprite_sheets.zip`

The archive must contain these three PNG files at its root:

- `hero_8dir_walk.png`
- `forest_slime_8dir.png`
- `fireball_8dir.png`

Each PNG is a 4-column × 8-row atlas with 32×32 cells. Direction rows are ordered down, down-right, right, up-right, up, up-left, left, down-left.

The archive is extracted automatically by `scripts/sprite_archive.gd` into `user://SkywardTales/sprites/` before the player and enemies are spawned.

**Repository upload note:** the archive has been prepared for this milestone but is not yet present in this branch. Add the supplied `sprite_sheets.zip` file here before running the game with the new art. The expected path is `assets/sprites/sprite_sheets.zip`.
