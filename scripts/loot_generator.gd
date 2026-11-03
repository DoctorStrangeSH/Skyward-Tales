extends RefCounted
class_name LootGenerator

## Rolls equipment with random rarity and affixes from data/loot_tables.json.
## Result is a normal item definition (slot, rarity, stats, name, icon,
## value) so equipping, comparing and selling need no special cases.

const PATH := "res://data/loot_tables.json"
const RARITY_ORDER := ["common", "uncommon", "rare", "epic"]

static var _tables: Dictionary = {}

static func tables() -> Dictionary:
	if _tables.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_tables = parsed
	return _tables

static func drop_chance() -> float:
	return float(tables().get("drop_chance", 0.0))

static func roll_rarity(rng: RandomNumberGenerator, minimum: String = "common") -> String:
	var weights: Dictionary = tables().get("rarity_weights", {"common": 1})
	var allowed: Array = RARITY_ORDER.slice(RARITY_ORDER.find(minimum))
	var total := 0.0
	for rarity in allowed:
		total += float(weights.get(rarity, 0))
	var pick := rng.randf() * total
	for rarity in allowed:
		pick -= float(weights.get(rarity, 0))
		if pick <= 0.0:
			return str(rarity)
	return str(allowed.back())

static func generate(rng: RandomNumberGenerator, level: int, rarity: String = "") -> Dictionary:
	var data := tables()
	var bases: Dictionary = data.get("bases", {})
	if bases.is_empty():
		return {}
	if rarity.is_empty():
		rarity = roll_rarity(rng)
	var rarity_data: Dictionary = data.get("rarities", {}).get(rarity, {"affixes": 1, "mult": 1.0, "value": 10})
	var base_id: String = bases.keys()[rng.randi_range(0, bases.size() - 1)]
	var base: Dictionary = bases[base_id]
	var definition: Dictionary = base.get("base", {}).duplicate(true)
	definition["slot"] = base.get("slot", "")
	definition["rarity"] = rarity
	definition["icon"] = base.get("icon", "")
	definition["generated"] = true
	var scale := float(rarity_data.get("mult", 1.0)) * (1.0 + 0.1 * float(maxi(0, level - 1)))
	var pool: Array = data.get("affixes", []).duplicate()
	var lines: Array[String] = []
	var first_suffix := ""
	for i in range(mini(int(rarity_data.get("affixes", 1)), pool.size())):
		var affix: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var amount := maxi(1, roundi(rng.randi_range(int(affix["min"]), int(affix["max"])) * scale))
		_add_stat(definition, str(affix["stat"]), amount)
		lines.append(str(affix["label"]) % amount)
		if first_suffix.is_empty():
			first_suffix = str(affix["suffix"])
	var names: Array = base.get("names", ["Предмет"])
	definition["name"] = "%s %s" % [names[rng.randi_range(0, names.size() - 1)], first_suffix]
	definition["description"] = ", ".join(lines)
	definition["value"] = int(rarity_data.get("value", 10)) + level * 2
	return definition

static func _add_stat(definition: Dictionary, stat: String, amount: int) -> void:
	if stat.begins_with("spell_bonus."):
		var spell := stat.trim_prefix("spell_bonus.")
		var bonus: Dictionary = definition.get("spell_bonus", {})
		bonus[spell] = int(bonus.get(spell, 0)) + amount
		definition["spell_bonus"] = bonus
	else:
		definition[stat] = int(definition.get(stat, 0)) + amount
