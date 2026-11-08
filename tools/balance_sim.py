"""Pacing model (owner's list №27/32): walks the story in order, adds quest
experience and one clear of every land's monsters (plus `--grind` extra
clears), and prints the hero's level at each chapter gate next to the gate's
required level. Used to tune the experience curve, land levels and gates.

    python3 tools/balance_sim.py [--grind 1]
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
XP_RATE = 0.6


def xp_to_next(level: int) -> int:
    """Mirror of PlayerCharacter.xp_for_level()."""
    return int(round(60 + 45 * (level - 1) ** 1.55))


def kind_xp() -> dict:
    main = (ROOT / "scripts" / "main.gd").read_text()
    result = {}
    for kind, script in re.findall(r'"(\w+)": preload\("res://scripts/(\w+)\.gd"\)', main):
        path = ROOT / "scripts" / f"{script}.gd"
        if path.exists():
            m = re.search(r"xp_reward = (\d+)", path.read_text())
            result[kind] = int(m.group(1)) if m else 14
    return result


def gap_xp(player: int, land: int) -> float:
    """Mirror of SkywardGame.gap_xp_mult(): little for farming low lands."""
    over = player - land - 3
    return 1.0 if over <= 0 else max(0.2, 1.0 - 0.15 * over)


# The story in order: (land visited, quests done there, gate to pass next).
PATH = [
    ("greenreach", ["main_prologue", "moonleaf_gathering"], "main_star_map"),
    ("greenreach", ["lost_cartographer_notes", "toren_wolf_hunt", "bran_supply_run", "farm_slimes", "main_star_map"], "grove_spirits"),
    ("ruins_depths", [], None),
    ("moonlit_grove", ["grove_spirits", "main_guardian", "lira_slime", "grove_shamans"], "crystal_heart"),
    ("haven", ["haven_letters", "haven_flour", "haven_kitten"], None),
    ("crystal_caves", ["crystal_heart", "main_echo", "caves_bats"], None),
    ("salt_coast", ["coast_crabs", "coast_light"], None),
    ("sky_island", ["main_bridge", "main_archive", "island_sentinels"], "main_spires"),
    ("misty_marsh", ["marsh_lanterns", "marsh_toads", "haven_seeds", "haven_songs"], None),
    ("wind_spires", ["main_spires", "main_tempest", "spires_wisps"], "main_rift"),
    ("stone_pass", ["pass_golems", "pass_coal", "coast_king", "marsh_king"], None),
    ("sky_rift", ["main_rift", "main_vail", "rift_shades"], "main_elder"),
    ("ashen_waste", ["main_elder", "ash_hounds", "ash_embers", "pass_giant", "borin_dream"], "main_echoes"),
    ("forge_depths", ["main_echoes", "ash_lord", "forge_titan", "borin_temper"], "main_ascent"),
    ("sky_heart", ["main_ascent", "main_heart"], None),
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--grind", type=float, default=0.0, help="extra clears of each land")
    args = parser.parse_args()
    regions = json.loads((ROOT / "data" / "regions.json").read_text())
    quests = {q["id"]: q for q in json.loads((ROOT / "data" / "quests.json").read_text())}
    gates = {}
    for link in json.loads((ROOT / "data" / "dialogues.json").read_text()).get("chain", []):
        gates[link.get("start")] = link
    kxp = kind_xp()
    level, xp, seen = 1, 0, set()

    def gain(amount: float) -> None:
        nonlocal level, xp
        xp += int(amount)
        while xp >= xp_to_next(level):
            xp -= xp_to_next(level)
            level += 1

    for land, done, gate in PATH:
        region = regions[land]
        clears = (0 if land in seen else 1) + args.grind
        seen.add(land)
        for _ in range(int(clears + 0.999)):
            for enemy in region.get("enemies", []):
                gain(kxp.get(enemy["kind"], 14) * float(region.get("enemy_power", 1.0)) * XP_RATE * gap_xp(level, int(region.get("level", 1))))
        for quest_id in done:
            gain(quests.get(quest_id, {}).get("reward", {}).get("experience", 0))
        need = gates.get(gate, {}).get("requires", gates.get(gate, {})).get("level", 0) if gate else 0
        mark = "" if not gate else (f"  gate {gate}: need {need} {'OK' if level >= need else 'GRIND'}")
        print(f"{land:14s} (lvl {region.get('level')}) → hero {level}{mark}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
