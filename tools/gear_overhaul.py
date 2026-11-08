"""Package C of the owner's list (9 ноября 2026): weapons in one or two
hands, shields, rings, earrings and cloaks, physical and magic stats.

    python3 tools/gear_overhaul.py && python3 tools/art/gear_icons.py

Idempotent: rewrites data/equipment.json, data/loot_tables.json and
data/merchant_stock.json in place.

Slots (player.equipment keys):
    blade     — the hand weapon: sword, dagger, spear, hammer, staff or bow
                ("hands": 2 — staves, bows, spears and heavy hammers);
    offhand   — a shield (only next to a one-handed weapon);
    armor, cloak, amulet, earrings, ring (two ring slots), relic.

New stats (all optional on an item):
    melee_pct / spell_pct      — % physical / magic damage;
    fire_pct, frost_pct, storm_pct — % to one element;
    crit_damage                — % added to the ×2 critical blow;
    resist                     — magic defence (like armour, vs spells);
    hp_regen                   — health every 5 seconds;
    mp_regen                   — extra mana per second;
    block                      — % of a blow a raised shield stops.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))

TWO_HANDED_KINDS = {"spear"}
TWO_HANDED = {"mountain_maul", "titan_breaker"}

NEW_ITEMS = {
    # Shields.
    "wooden_shield": {"name": "Деревянный щит", "description": "Доски, стянутые железом. С ним можно блокировать (F) и парировать.", "slot": "offhand", "rarity": "common", "armor": 1, "block": 30, "value": 30},
    "iron_shield": {"name": "Окованный щит", "description": "Работа Борина: дуб под железной полосой.", "slot": "offhand", "rarity": "uncommon", "armor": 3, "block": 40, "value": 90},
    "guard_shield": {"name": "Щит стражника", "description": "Высокий щит гарнизона Гавани. Держит и стрелы, и заклятья.", "slot": "offhand", "rarity": "rare", "armor": 5, "block": 50, "resist": 2, "value": 200},
    "sky_aegis": {"name": "Небесная эгида", "description": "Щит из небесной стали: лёгкий, как облако, и твёрдый, как утёс.", "slot": "offhand", "rarity": "epic", "armor": 7, "block": 55, "resist": 5, "value": 560},
    # Rings.
    "copper_ring": {"name": "Медное кольцо", "description": "Простое кольцо на удачу.", "slot": "ring", "rarity": "common", "crit": 2, "value": 40},
    "ember_ring": {"name": "Кольцо углей", "description": "Тёплое даже зимой.", "slot": "ring", "rarity": "uncommon", "fire_pct": 10, "value": 110},
    "frost_ring": {"name": "Кольцо инея", "description": "На камне никогда не тает иней.", "slot": "ring", "rarity": "uncommon", "frost_pct": 10, "value": 110},
    "storm_ring": {"name": "Кольцо грозы", "description": "Покалывает палец перед грозой.", "slot": "ring", "rarity": "uncommon", "storm_pct": 10, "value": 110},
    "vigor_ring": {"name": "Кольцо бодрости", "description": "Раны под ним затягиваются быстрее.", "slot": "ring", "rarity": "rare", "hp_regen": 3, "max_health": 10, "value": 240},
    "duelist_ring": {"name": "Перстень дуэлянта", "description": "Перстень мастера клинка из Вольной пристани.", "slot": "ring", "rarity": "rare", "crit": 4, "crit_damage": 20, "value": 260},
    # Earrings.
    "silver_earrings": {"name": "Серебряные серьги", "description": "Серебро отводит дурной глаз и чужие чары.", "slot": "earrings", "rarity": "uncommon", "resist": 3, "max_mana": 10, "value": 120},
    "wind_earrings": {"name": "Серьги ветра", "description": "Звенят, как колокольчики на шпилях.", "slot": "earrings", "rarity": "rare", "agility": 3, "mp_regen": 1, "value": 230},
    "sage_earrings": {"name": "Серьги мудреца", "description": "В них слышно, как думает мир.", "slot": "earrings", "rarity": "rare", "spell_pct": 8, "will": 2, "value": 260},
    # Cloaks.
    "travel_cloak": {"name": "Дорожный плащ", "description": "Шерстяной плащ странника. Чуть греет и чуть бережёт от чар.", "slot": "cloak", "rarity": "common", "armor": 1, "resist": 1, "value": 35},
    "hunter_cloak": {"name": "Плащ охотника", "description": "Пятнистый, как лесная тень.", "slot": "cloak", "rarity": "uncommon", "agility": 2, "melee_pct": 5, "value": 120},
}

# Old armour pieces that are cloaks and shields now.
MOVED = {"ash_cloak": "cloak", "mirage_cloak": "cloak", "crab_aegis": "offhand"}
CRAB_AEGIS = {"armor": 6, "block": 60}

BASES = {
    "blade": {"slot": "blade", "names": ["Меч", "Клинок", "Сабля"], "icon": "iron_sword", "base": {"melee": 3}, "weight": 2},
    "dagger": {"slot": "blade", "kind": "dagger", "names": ["Кинжал", "Нож", "Стилет"], "icon": "scout_knife", "base": {"melee": 2, "crit": 3}},
    "mace": {"slot": "blade", "kind": "hammer", "names": ["Булава", "Кистень"], "icon": "smith_hammer", "base": {"melee": 4}},
    "spear": {"slot": "blade", "kind": "spear", "hands": 2, "names": ["Копьё", "Пика", "Глефа"], "icon": "guard_spear", "base": {"melee": 5}},
    "maul": {"slot": "blade", "kind": "hammer", "hands": 2, "names": ["Молот", "Боевой молот"], "icon": "mountain_maul", "base": {"melee": 7}, "weight": 0.7},
    "staff": {"slot": "blade", "kind": "staff", "hands": 2, "names": ["Посох", "Жезл"], "icon": "apprentice_staff", "base": {"spell_bonus": {"*": 4}}},
    "bow": {"slot": "blade", "kind": "bow", "bow": True, "hands": 2, "names": ["Лук", "Длинный лук"], "icon": "hunting_bow", "base": {"ranged": 4}, "weight": 0.8},
    "shield": {"slot": "offhand", "names": ["Щит", "Баклер", "Круглый щит"], "icon": "wooden_shield", "base": {"armor": 2, "block": 30}, "weight": 0.9},
    "robe": {"slot": "armor", "names": ["Мантия", "Куртка", "Кольчуга"], "icon": "leather_armor", "base": {"armor": 2}},
    "cloak": {"slot": "cloak", "names": ["Плащ", "Накидка"], "icon": "travel_cloak", "base": {"armor": 1}, "weight": 0.8},
    "amulet": {"slot": "amulet", "names": ["Амулет", "Кулон"], "icon": "mana_amulet", "base": {"max_mana": 8}},
    "ring": {"slot": "ring", "names": ["Кольцо", "Перстень"], "icon": "copper_ring", "base": {}, "weight": 1.2},
    "earrings": {"slot": "earrings", "names": ["Серьги"], "icon": "silver_earrings", "base": {}, "weight": 0.7},
    "relic": {"slot": "relic", "names": ["Талисман", "Оберег"], "icon": "storm_eye", "base": {}},
}

NEW_AFFIXES = [
    {"id": "might", "stat": "melee_pct", "min": 3, "max": 6, "pct": True, "suffix": "мощи", "label": "+%d%% к физическому урону"},
    {"id": "arcana", "stat": "spell_pct", "min": 3, "max": 6, "pct": True, "suffix": "чародея", "label": "+%d%% к магическому урону"},
    {"id": "blaze", "stat": "fire_pct", "min": 5, "max": 10, "pct": True, "suffix": "зноя", "label": "+%d%% к урону огнём"},
    {"id": "rime", "stat": "frost_pct", "min": 5, "max": 10, "pct": True, "suffix": "стужи", "label": "+%d%% к урону льдом"},
    {"id": "thunder", "stat": "storm_pct", "min": 5, "max": 10, "pct": True, "suffix": "грома", "label": "+%d%% к урону молнией"},
    {"id": "fury", "stat": "crit_damage", "min": 8, "max": 15, "pct": True, "suffix": "ярости", "label": "+%d%% к критическому урону"},
    {"id": "ward", "stat": "resist", "min": 1, "max": 3, "suffix": "оберега", "label": "+%d к магической защите"},
    {"id": "mend", "stat": "hp_regen", "min": 1, "max": 2, "suffix": "исцеления", "label": "+%d здоровья раз в 5 с"},
    {"id": "font", "stat": "mp_regen", "min": 1, "max": 1, "suffix": "родника", "label": "+%d маны в секунду"},
]

# Where the new pieces can be bought.
BRAN_OFFERS = {
    "wooden_shield": {"name": "Деревянный щит", "description": "Щит для блока и парирования (F)", "base_price": 45},
    "travel_cloak": {"name": "Дорожный плащ", "description": "+1 к броне, +1 к магической защите", "base_price": 50},
    "copper_ring": {"name": "Медное кольцо", "description": "+2% к шансу крита", "base_price": 60},
    "silver_earrings": {"name": "Серебряные серьги", "description": "+3 к магической защите, +10 маны", "base_price": 150, "required_bran_trust": 20},
}
SELL_PRICES = {"wooden_shield": 12, "travel_cloak": 14, "copper_ring": 18, "silver_earrings": 50}


def main() -> int:
    eq_path = ROOT / "data" / "equipment.json"
    data = json.loads(eq_path.read_text(encoding="utf-8"))
    items: dict = data["items"]
    for item_id, item in items.items():
        slot = item.get("slot", "")
        if slot == "weapon":
            item["slot"] = "blade"
            item["hands"] = 2
            item["kind"] = "bow" if item.get("bow") else "staff"
        elif slot == "blade":
            two = item_id in TWO_HANDED or item.get("kind") in TWO_HANDED_KINDS
            item["hands"] = 2 if two else 1
        if item_id in MOVED:
            item["slot"] = MOVED[item_id]
            if item_id == "crab_aegis":
                item.update(CRAB_AEGIS)
    for item_id, item in NEW_ITEMS.items():
        items[item_id] = item
    eq_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    loot_path = ROOT / "data" / "loot_tables.json"
    loot = json.loads(loot_path.read_text(encoding="utf-8"))
    loot["bases"] = BASES
    known = {a["id"] for a in loot["affixes"]}
    loot["affixes"] += [a for a in NEW_AFFIXES if a["id"] not in known]
    for affix in loot["affixes"]:
        if affix["id"] == "edge":
            affix["label"] = "+%d к урону оружием"
    # Legendaries come from bosses and mini-bosses; ordinary foes almost never.
    loot["rarity_weights"] = {"common": 55, "uncommon": 30, "rare": 11, "epic": 3.4, "legendary": 0.05}
    loot["elite_rarity_weights"] = {"common": 0, "uncommon": 45, "rare": 35, "epic": 17, "legendary": 3}
    loot["boss_rarity_weights"] = {"common": 0, "uncommon": 0, "rare": 50, "epic": 35, "legendary": 15}
    loot["shield_block"] = {"common": 30, "uncommon": 35, "rare": 40, "epic": 45, "legendary": 50}
    loot_path.write_text(json.dumps(loot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    shop_path = ROOT / "data" / "merchant_stock.json"
    shop = json.loads(shop_path.read_text(encoding="utf-8"))
    shop["offers"].update(BRAN_OFFERS)
    shop["sell_prices"].update(SELL_PRICES)
    shop_path.write_text(json.dumps(shop, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"items: {len(items)}, bases: {len(BASES)}, affixes: {len(loot['affixes'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
