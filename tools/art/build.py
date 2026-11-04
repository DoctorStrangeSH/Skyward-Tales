#!/usr/bin/env python3
"""Generates all Skyward Tales pixel art from code.

Usage: python3 tools/art/build.py [--only world|characters|props] [--preview DIR]
Reads region geometry from data/regions.json and writes PNGs under assets/.
The output is deterministic: running it twice produces identical files.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))

import characters  # noqa: E402
import creatures  # noqa: E402
import flora  # noqa: E402
import icons  # noqa: E402
import chests  # noqa: E402
import apron  # noqa: E402
import title_art  # noqa: E402
import gates  # noqa: E402
import minimap  # noqa: E402
import recolor  # noqa: E402
import props  # noqa: E402
import terrain  # noqa: E402
from palettes import ISLAND_STYLES, STYLES  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORLD = ROOT / "assets" / "world"
manifest: dict = {}


def save(canvas, rel: str, origin=None) -> None:
    path = ROOT / "assets" / rel
    canvas.save(path)
    entry = {"size": [canvas.w, canvas.h]}
    if origin is not None:
        entry["origin"] = list(origin)
    manifest[rel] = entry
    print(f"  {rel} {canvas.w}x{canvas.h}")


def build_world() -> None:
    regions = json.loads((ROOT / "data" / "regions.json").read_text())
    for variant in range(3):
        for night in (False, True):
            canvas, origin = apron.cloud_puff(900 + variant, night)
            save(canvas, f"world/cloud_puff_{'night' if night else 'day'}_{variant}.png", origin)
    for index, (region_id, region) in enumerate(regions.items()):
        t = region.get("terrain")
        if not t:
            continue
        style = t.get("style", "day")
        pal = STYLES[style]
        glow = pal.get("glow")
        print(f"region {region_id} ({style})")
        crypt = style == "crypt"
        ground = terrain.render_crypt(t, pal, seed=100 + index * 17) if crypt else terrain.render_ground(t, pal, seed=100 + index * 17)
        save(ground, f"world/{region_id}_ground.png")
        w, h = t["size"]
        if crypt:
            from pixel import Canvas as _Canvas
            save(_Canvas(w, h), f"world/{region_id}_canopy.png")
            for variant in range(3):
                canvas, origin = flora.stone_spire(300 + index * 10 + variant, pal, "large" if variant != 2 else "small")
                save(canvas, f"world/{style}_tree_{variant}.png", origin)
            for variant in range(2):
                canvas, origin = flora.rock_pile(400 + index * 10 + variant, pal)
                save(canvas, f"world/{style}_bush_{variant}.png", origin)
            continue
        border_pal = dict(pal, leaf=pal["cloud"], outline=pal["cloud"][0]) if style in ISLAND_STYLES else pal
        if style not in ("cave", "crypt"):
            apron_terrain = dict(t, _gates=[g["position"] for g in region.get("gates", [])])
            for side, strip in apron.render(apron_terrain, pal, seed=500 + index).items():
                save(strip, f"world/{region_id}_apron_{side}.png")
        save(flora.canopy_border(w, h, border_pal, seed=200 + index, glow=glow), f"world/{region_id}_canopy.png")
        for variant in range(3):
            size = "large" if variant != 2 else "small"
            if style in ("cave", "rift"):
                canvas, origin = flora.crystal_cluster(300 + index * 10 + variant, pal, size)
            elif style == "mountain":
                canvas, origin = flora.pine(300 + index * 10 + variant, pal, size)
            elif style == "coast":
                canvas, origin = flora.palm(300 + index * 10 + variant, pal, size)
            elif style == "spires":
                canvas, origin = flora.stone_spire(300 + index * 10 + variant, pal, size)
            elif style == "ash":
                canvas, origin = flora.dead_tree(300 + index * 10 + variant, pal, size)
            else:
                canvas, origin = flora.tree(300 + index * 10 + variant, pal, size, glow=glow)
            save(canvas, f"world/{style}_tree_{variant}.png", origin)
        for variant in range(2):
            if style in ("cave", "rift", "ash"):
                canvas, origin = flora.rock_pile(400 + index * 10 + variant, pal)
            else:
                canvas, origin = flora.bush(400 + index * 10 + variant, pal, glow=glow)
            save(canvas, f"world/{style}_bush_{variant}.png", origin)
    day, night = STYLES["day"], STYLES["night"]
    canvas, origin = props.ruins(day)
    save(canvas, "world/ruins.png", origin)
    canvas, origin = props.standing_stones(night)
    save(canvas, "world/standing_stones.png", origin)
    canvas, origin = props.crystal_altar(STYLES["cave"])
    save(canvas, "world/crystal_altar.png", origin)
    canvas, origin = props.sky_archive(STYLES["sky"])
    save(canvas, "world/sky_archive.png", origin)


def build_characters() -> None:
    print("characters")
    save(characters.sheet(characters.HERO), "sprites/characters/hero_8dir_walk.png")
    save(characters.cast_sheet(characters.HERO), "sprites/characters/hero_8dir_cast.png")
    save(characters.sheet(characters.HERO_F), "sprites/characters/hero_f_8dir_walk.png")
    save(characters.cast_sheet(characters.HERO_F), "sprites/characters/hero_f_8dir_cast.png")
    for npc_id, look in characters.NPCS.items():
        save(characters.portrait_sheet(look), f"sprites/npcs/{npc_id}.png")
    save(characters.sheet(characters.SHAMAN), "sprites/enemies/forest_shaman_8dir.png")
    save(characters.sheet(characters.NPCS["vail"]), "sprites/enemies/vail_8dir.png")
    save(characters.sheet(characters.SHADE), "sprites/enemies/rift_shade_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.slime, 32)), "sprites/enemies/forest_slime_true8.png")
    save(creatures.soften(creatures.build_sheet(creatures.wolf, 32)), "sprites/enemies/forest_wolf_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.guardian, 48)), "sprites/enemies/grove_guardian_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.bat, 32)), "sprites/enemies/cave_bat_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.echo_warden, 48)), "sprites/enemies/echo_warden_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.sentinel, 32)), "sprites/enemies/sky_sentinel_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.wisp, 32)), "sprites/enemies/wind_wisp_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.toad, 32)), "sprites/enemies/marsh_toad_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.crab, 32)), "sprites/enemies/coast_crab_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.golem, 32)), "sprites/enemies/stone_golem_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.giant, 48)), "sprites/enemies/mountain_giant_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.crab_king, 48)), "sprites/enemies/crab_king_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.bog_king, 48)), "sprites/enemies/bog_king_8dir.png")
    save(creatures.soften(creatures.build_sheet(creatures.tempest, 48)), "sprites/enemies/tempest_colossus_8dir.png")
    save(creatures.build_sheet(creatures.projectile("fire"), 32), "sprites/magic/fireball_8dir.png")
    save(creatures.build_sheet(creatures.projectile("frost"), 32), "sprites/magic/frostbolt_8dir.png")
    save(creatures.build_sheet(creatures.projectile("lightning"), 32), "sprites/magic/chain_lightning_8dir.png")


def build_props() -> None:
    print("props")
    items = {
        "chest_closed": props.chest(False), "chest_open": props.chest(True),
        "moonleaf": props.herb("moonleaf"), "spirit_blossom": props.herb("spirit_blossom"),
        "ore_node": props.ore_node(), "supply_crate": props.crate(), "map_fragment": props.scroll(),
        "health_potion": props.potion("red"), "mana_potion": props.potion("blue"),
        "wolf_pelt": props.pelt(), "relic": props.treasure("relic"), "pouch": props.treasure("pouch"),
        "gate_day": props.gate(False), "gate_night": props.gate(True), "gate_cave": props.cave_gate(), "gate_sky": props.sky_gate(), "gate_spires": props.sky_gate(), "gate_rift": props.sky_gate(), "gate_marsh": props.gate(False),
        "gate_coast": props.gate(False), "gate_mountain": props.gate(False), "gate_crypt": props.cave_gate(), "coal_sack": props.crate(),
        "waystone_on": props.waystone(True), "waystone_off": props.waystone(False),
        "marsh_lantern": props.herb("marsh_lantern"),
        "ember_coal": props.herb("ember_coal"),
        "rift_throne": props.rune_circle(("#fbf6ff", "#e6d2ff", "#c9a2ff", "#6a3ac0")),
        "wind_rune": props.herb("wind_rune"), "storm_heart": props.rune_circle(("#ffffff", "#c8f4ff", "#7ad0f0", "#3a7ab0")),
        "memory_crystal": props.herb("memory_crystal"),
        "echo_crystal": props.herb("echo_crystal"), "sky_shard": props.sky_shard(), "altar_heart": props.rune_circle(),
        "marker_quest": props.marker("quest"), "marker_ready": props.marker("ready"),
        "marker_service": props.marker("service"), "key_e": props.key_badge(),
    }
    items.update(chests.build())
    items.update(gates.build())
    for rel, canvas in title_art.build().items():
        save(canvas, rel)
    for name, (canvas, origin) in items.items():
        save(canvas, f"props/{name}.png", origin)
    save(props.app_icon(), "icon.png")
    for item_id, canvas in icons.build().items():
        save(canvas, f"icons/{item_id}.png")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=["world", "characters", "props", "minimap"], default=None)
    args = parser.parse_args()
    if args.only in (None, "world", "minimap"):
        if args.only != "minimap":
            build_world()
        for region_id, region in json.loads((ROOT / "data" / "regions.json").read_text()).items():
            if region.get("terrain"):
                minimap.build(ROOT, region_id, region["terrain"])
    if False:
        build_world()
    if args.only in (None, "characters"):
        build_characters()
        recolor.build(ROOT)
    if args.only in (None, "props"):
        build_props()
    manifest_path = ROOT / "assets" / "art_manifest.json"
    existing = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    existing.update(manifest)
    manifest_path.write_text(json.dumps(dict(sorted(existing.items())), indent=1) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
