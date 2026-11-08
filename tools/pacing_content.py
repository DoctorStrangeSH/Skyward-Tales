"""Pacing content (owner's list №27/32, 9 ноября 2026): the story lands had
only 3–5 monsters each, so the story raced ahead. This adds monsters to them
(spots chosen on open ground, away from trees, props, NPCs and gates) and a
new side quest with its own NPC in each, so there is something to do — and
someone to help — between the chapter gates. Talk lines: tools/npc_book.py.

    python3 tools/pacing_content.py && python3 tools/npc_book.py
"""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import jsonfmt  # noqa: E402

# land: (extra monsters [(kind, count)], NPC, quest)
CONTENT = {
    "greenreach": (
        [("slime", 5), ("wolf", 2)],
        {"id": "farmer_gavrila", "name": "Фермер Гаврила", "look": "settler_woodcutter", "position": [1120, 870]},
        {"id": "farm_slimes", "title": "Слизь в капусте", "description": "Слизни облюбовали огороды Гаврилы на юго-востоке Пределов. Прогоните восьмерых.", "target": 8, "side": True, "kill_kind": "slime", "requires_quest": "moonleaf_gathering", "reward": {"experience": 90, "gold": 40, "items": [{"id": "bread", "amount": 3}]}},
    ),
    "moonlit_grove": (
        [("wolf", 3), ("shaman", 2)],
        {"id": "grove_herbalist", "name": "Елисей, собиратель грибов", "look": "settler_cook", "position": [400, 600]},
        {"id": "grove_shamans", "title": "Шёпот шаманов", "description": "Лесные шаманы сбились с ума от пыли и путают грибникам тропы. Успокойте четырёх.", "target": 4, "side": True, "kill_kind": "shaman", "reward": {"experience": 180, "gold": 60, "items": [{"id": "mana_potion", "amount": 2}]}},
    ),
    "crystal_caves": (
        [("bat", 4), ("golem", 2)],
        {"id": "caves_miner_senya", "name": "Сеня, молодой рудокоп", "look": "pass_miner", "position": [500, 500]},
        {"id": "caves_bats", "title": "Тьма под крыльями", "description": "Летучие мыши гасят фонари рудокопов. Прогоните восемь, чтобы в штольнях снова стало светло.", "target": 8, "side": True, "kill_kind": "bat", "reward": {"experience": 320, "gold": 90, "items": [{"id": "iron_ore", "amount": 4}]}},
    ),
    "sky_island": (
        [("sentinel", 4), ("wisp", 2)],
        {"id": "archive_scribe", "name": "Писарь Тимон", "look": "librarian", "position": [304, 304]},
        {"id": "island_sentinels", "title": "Сломанные стражи", "description": "Стражи-автоматы города Хранителей сбились и нападают на всех. Остановите шестерых — писарь хочет переписать их приказы.", "target": 6, "side": True, "kill_kind": "sentinel", "requires_quest": "main_bridge", "reward": {"experience": 520, "gold": 140, "items": [{"id": "wind_essence", "amount": 2}]}},
    ),
    "wind_spires": (
        [("wisp", 4), ("sentinel", 2)],
        {"id": "spires_keeper", "name": "Смотритель шпилей Брим", "look": "guard", "position": [904, 304]},
        {"id": "spires_wisps", "title": "Блуждающие огни", "description": "Ветряные огоньки сбивают с пути всех, кто поднимается на шпили. Развейте восемь.", "target": 8, "side": True, "kill_kind": "wisp", "reward": {"experience": 700, "gold": 180, "items": [{"id": "wind_essence", "amount": 3}]}},
    ),
    "sky_rift": (
        [("shade", 4), ("sentinel", 2)],
        {"id": "rift_runaway", "name": "Беглый послушник Ян", "look": "herald", "position": [304, 304]},
        {"id": "rift_shades", "title": "Тени без имён", "description": "Тени Расколотого острова — это те, кого Узор забыл. Освободите шесть — послушник прочитает над ними имена.", "target": 6, "side": True, "kill_kind": "shade", "reward": {"experience": 1000, "gold": 220, "items": [{"id": "shadow_essence", "amount": 3}]}},
    ),
}


# (x, y, radius) kept free of monsters: the hero's start in the Reaches.
SAFE_ZONES = {"greenreach": [(270, 625, 460)]}


def obstacles(region: dict) -> list:
    terrain = region["terrain"]
    found = [(t[0], t[1], 40) for t in terrain.get("trees", [])]
    found += [(p["position"][0], p["position"][1], 70) for p in terrain.get("props", [])]
    found += [(b["center"][0], b["center"][1], max(b["size"]) / 2 + 14) for b in terrain.get("blockers", [])]
    for key in ("npcs", "chests", "herbs", "gather", "enemies", "lore"):
        found += [(n["position"][0], n["position"][1], 46) for n in region.get(key, []) or []]
    found += [(g["position"][0], g["position"][1], 160) for g in region.get("gates", [])]
    # Nothing waits at the hero's first steps in the village.
    found += SAFE_ZONES.get(region.get("_id", ""), [])
    for pond in terrain.get("ponds", []):
        if "circle" in pond:
            found.append((pond["circle"][0], pond["circle"][1], pond["circle"][2] + 24))
    for key in ("waystone", "dock", "fate_crystal"):
        if region.get(key):
            found.append((region[key][0], region[key][1], 80))
    return found


def free_spots(region: dict, count: int, seed: int) -> list:
    width, height = region["terrain"]["size"]
    margin = int(region["terrain"].get("edge_margin", 0)) + 70
    rng = random.Random(seed)
    spots: list = []
    blocked = obstacles(region)
    tries = 0
    while len(spots) < count and tries < 4000:
        tries += 1
        x, y = rng.randint(margin, width - margin), rng.randint(margin, height - margin)
        if any((x - ox) ** 2 + (y - oy) ** 2 < r * r for ox, oy, r in blocked):
            continue
        if any((x - sx) ** 2 + (y - sy) ** 2 < 120 ** 2 for sx, sy in spots):
            continue
        spots.append((x, y))
    return spots


def main() -> int:
    regions_path = ROOT / "data" / "regions.json"
    quests_path = ROOT / "data" / "quests.json"
    givers_path = ROOT / "data" / "quest_givers.json"
    regions = json.loads(regions_path.read_text(encoding="utf-8"))
    quests = json.loads(quests_path.read_text(encoding="utf-8"))
    givers = json.loads(givers_path.read_text(encoding="utf-8"))
    known_quests = {q["id"] for q in quests}
    for land, (monsters, npc, quest) in CONTENT.items():
        region = regions[land]
        region["_id"] = land
        region["enemies"] = [e for e in region["enemies"] if not e.get("pacing")]
        region["npcs"] = [n for n in region["npcs"] if n["id"] != npc["id"]]
        region["npcs"].append(npc)
        total = sum(n for _, n in monsters)
        spots = free_spots(region, total, sum(ord(c) for c in land))
        index = 0
        for kind, count in monsters:
            for _ in range(count):
                if index >= len(spots):
                    break
                region["enemies"].append({"kind": kind, "position": list(spots[index]), "pacing": True})
                index += 1
        if quest["id"] not in known_quests:
            quests.append(quest)
        else:
            quests = [quest if q["id"] == quest["id"] else q for q in quests]
        givers.setdefault(npc["id"], {"speaker": npc["name"], "quests": [], "idle": "…"})
        givers[npc["id"]]["speaker"] = npc["name"]
        givers[npc["id"]]["quests"] = [quest["id"]]
        del region["_id"]
        print(f"{land}: +{index} monsters, {npc['name']} — «{quest['title']}»")
    regions_path.write_text(jsonfmt.dumps(regions) + "\n", encoding="utf-8")
    quests_path.write_text(json.dumps(quests, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    givers_path.write_text(json.dumps(givers, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
