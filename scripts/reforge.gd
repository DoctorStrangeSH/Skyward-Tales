extends Node
class_name Reforge

## Этап 24: Borin's reforging and trophy forging.
## Reforging: one property of a rolled item is struck off and forged anew
## (another property of the loot tables, rolled at the item's level). The
## old one can be taken back — the price is paid either way — so a good roll
## is kept and a bad one costs only coin. Each reforging of the same item
## costs more. Forged (+N) pieces are not reforged: reforge first, sharpen
## after.
## Trophy forging: a boss beaten before trophies existed (an old save) — Borin
## forges its trophy from an ancient relic and gold.

const TROPHY_COST := {"gold": 250, "materials": {"ancient_relic": 1}}

var game: SkywardGame
## The last reforging, until a choice is made: {"item", "index", "old", "new"}.
var pending: Dictionary = {}

# --- Properties of a rolled item ----------------------------------------------

## [{"id", "amount"}] — stored on new items, read back from the description
## line by line on items rolled before reforging existed.
static func affixes_of(definition: Dictionary) -> Array:
	if definition.get("affixes", null) is Array:
		return (definition["affixes"] as Array).duplicate(true)
	var result: Array = []
	for line in str(definition.get("description", "")).split(", "):
		for entry in LootGenerator.tables().get("affixes", []):
			var label := str(entry.get("label", ""))
			var parts := label.split("%d")
			if parts.size() != 2:
				continue
			var tail := parts[1].replace("%%", "%")
			if line.begins_with(parts[0]) and line.ends_with(tail):
				var number := line.trim_prefix(parts[0]).trim_suffix(tail)
				if number.is_valid_int():
					result.append({"id": str(entry["id"]), "amount": int(number)})
					break
	return result

static func line_of(entry: Dictionary) -> String:
	var info := LootGenerator.affix(str(entry.get("id", "")))
	return (str(info.get("label", "%d")) % int(entry.get("amount", 0))) if not info.is_empty() else ""

static func _shift(definition: Dictionary, entry: Dictionary, direction: int) -> void:
	var info := LootGenerator.affix(str(entry.get("id", "")))
	if info.is_empty():
		return
	var stat := str(info["stat"])
	var amount := int(entry.get("amount", 0)) * direction
	if stat.begins_with("spell_bonus."):
		var spell := stat.trim_prefix("spell_bonus.")
		var bonus: Dictionary = definition.get("spell_bonus", {})
		bonus[spell] = int(bonus.get(spell, 0)) + amount
		if int(bonus[spell]) == 0:
			bonus.erase(spell)
		definition["spell_bonus"] = bonus
	else:
		definition[stat] = int(definition.get(stat, 0)) + amount
		if int(definition[stat]) == 0:
			definition.erase(stat)

static func _describe(definition: Dictionary, affixes: Array) -> void:
	var lines: Array[String] = []
	for entry in affixes:
		lines.append(line_of(entry))
	definition["description"] = ", ".join(lines)
	definition["affixes"] = affixes

# --- Reforging -------------------------------------------------------------------

func can_reforge(item_id: String) -> bool:
	var definition := game.player.get_item_definition(item_id)
	return bool(definition.get("generated", false)) and int(definition.get("upgrade", 0)) == 0 and not definition.has("base_id") and not affixes_of(definition).is_empty()

func cost(item_id: String) -> Dictionary:
	var definition := game.player.get_item_definition(item_id)
	var rarity := str(definition.get("rarity", "common"))
	var times := 1 + int(definition.get("reforged", 0))
	var materials := {"iron_ore": 2}
	if rarity in ["epic", "legendary"]:
		materials["wind_essence"] = 1
	return {"gold": roundi(50.0 * float(PlayerCharacter.RARITY_COST.get(rarity, 1.0)) * float(times)), "materials": materials}

## Items to reforge: worn first, then the bag.
func candidates() -> Array:
	var result: Array = []
	var hero := game.player
	for slot in hero.equipment:
		var id := str(hero.equipment[slot])
		if not id.is_empty() and can_reforge(id):
			result.append(id)
	for item_id in hero.inventory:
		var id := str(item_id)
		if not result.has(id) and can_reforge(id):
			result.append(id)
	return result

## Strikes property `index` off and forges a new one. Returns the new entry
## ({} when it could not be done: unpaid, a wrong index).
func reforge(item_id: String, index: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if not can_reforge(item_id):
		return {}
	var hero := game.player
	var definition: Dictionary = hero.generated_items.get(item_id, {})
	var affixes := affixes_of(definition)
	if index < 0 or index >= affixes.size():
		return {}
	var price := cost(item_id)
	if not hero.can_pay(price):
		return {}
	hero.add_gold(-int(price["gold"]))
	var materials: Dictionary = price["materials"]
	for material in materials:
		hero.remove_item(str(material), int(materials[material]))
	var roll := rng if rng != null else game.loot_rng
	var taken: Array = []
	for entry in affixes:
		taken.append(str(entry["id"]))
	var pool: Array = []
	for entry in LootGenerator.tables().get("affixes", []):
		if not taken.has(str(entry["id"])):
			pool.append(entry)
	var old: Dictionary = affixes[index]
	var info: Dictionary = pool[roll.randi_range(0, pool.size() - 1)] if not pool.is_empty() else LootGenerator.affix(str(old["id"]))
	var level := int(definition.get("level", hero.level))
	var rarity_data: Dictionary = LootGenerator.tables().get("rarities", {}).get(str(definition.get("rarity", "common")), {"mult": 1.0})
	var growth := 0.03 if bool(info.get("pct", false)) else 0.1
	var scale := float(rarity_data.get("mult", 1.0)) * (1.0 + growth * float(maxi(0, level - 1)))
	var fresh := {"id": str(info["id"]), "amount": maxi(1, roundi(roll.randi_range(int(info["min"]), int(info["max"])) * scale))}
	_shift(definition, old, -1)
	_shift(definition, fresh, 1)
	affixes[index] = fresh
	_describe(definition, affixes)
	definition["reforged"] = int(definition.get("reforged", 0)) + 1
	hero.generated_items[item_id] = definition
	pending = {"item": item_id, "index": index, "old": old, "new": fresh}
	hero.stats_changed.emit()
	game.achievements.add("reforged")
	return fresh

## Takes the old property back after a reforging (the price stays paid).
func revert() -> bool:
	if pending.is_empty():
		return false
	var hero := game.player
	var item_id := str(pending["item"])
	var definition: Dictionary = hero.generated_items.get(item_id, {})
	var affixes := affixes_of(definition)
	var index := int(pending["index"])
	if definition.is_empty() or index >= affixes.size():
		pending = {}
		return false
	_shift(definition, affixes[index], -1)
	_shift(definition, pending["old"], 1)
	affixes[index] = pending["old"]
	_describe(definition, affixes)
	hero.generated_items[item_id] = definition
	pending = {}
	hero.stats_changed.emit()
	return true

# --- Borin's dialogue ------------------------------------------------------------

func open_list() -> void:
	pending = {}
	var choices: Array[Dictionary] = []
	for item_id in candidates().slice(0, 7):
		var mark := "" if game.player.can_pay(cost(item_id)) else "✗ "
		choices.append({"id": "reforge_item:" + str(item_id), "label": "%s%s — %s" % [mark, game.player.get_item_name(item_id), game.borin.cost_text(cost(item_id))]})
	choices.append({"id": "borin_later", "label": "Хватит"})
	var line := "Одно свойство собью, другое выкую. Не понравится — верну старое, но работа есть работа: плату не возвращаю. Перековывать можно только незаточенное."
	if choices.size() == 1:
		line = "Перековать нечего: несу только найденные вещи со свойствами, и незаточенные."
	game._show_dialogue_choices("Борин, кузнец", line, choices)

func _open_item(item_id: String) -> void:
	var choices: Array[Dictionary] = []
	var affixes := affixes_of(game.player.get_item_definition(item_id))
	for i in affixes.size():
		choices.append({"id": "reforge_line:%s:%d" % [item_id, i], "label": "Перековать «%s»" % line_of(affixes[i])})
	choices.append({"id": "borin_reforge", "label": "← Другая вещь"})
	game._show_dialogue_choices("Борин, кузнец", "%s. Какое свойство перековать? Цена: %s." % [game.player.get_item_name(item_id), game.borin.cost_text(cost(item_id))], choices)

func open_trophies() -> void:
	var choices: Array[Dictionary] = []
	for kind in game.signature.missing():
		var item_id := SignatureGear.trophy_of(kind)
		var mark := "" if game.player.can_pay(TROPHY_COST) else "✗ "
		choices.append({"id": "trophy_forge:" + kind, "label": "%s%s — %s" % [mark, game.player.get_item_name(item_id), game.borin.cost_text(TROPHY_COST)]})
	choices.append({"id": "borin_later", "label": "Хватит"})
	game._show_dialogue_choices("Борин, кузнец", "Ты бил великих врагов, а трофеев не принёс? Расскажи, каким был враг, — и дай древнюю реликвию: из её металла выкую вещь по его подобию.", choices)

func forge_trophy(kind: String) -> bool:
	if not game.signature.missing().has(kind) or not game.player.can_pay(TROPHY_COST):
		return false
	game.player.add_gold(-int(TROPHY_COST["gold"]))
	var materials: Dictionary = TROPHY_COST["materials"]
	for material in materials:
		game.player.remove_item(str(material), int(materials[material]))
	game.director.set_flag("trophy_" + kind)
	game.achievements.add("trophies")
	game.player.add_item(SignatureGear.trophy_of(kind), 1)
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "borin_reforge":
		open_list()
		return true
	if choice_id == "borin_trophies":
		open_trophies()
		return true
	if choice_id == "reforge_keep":
		pending = {}
		open_list()
		return true
	if choice_id == "reforge_revert":
		var item_id := str(pending.get("item", ""))
		revert()
		if not item_id.is_empty():
			game.hud.show_message("Вернули старое: %s." % game.player.get_item_name(item_id), 2.5)
		open_list()
		return true
	if choice_id.begins_with("reforge_item:"):
		_open_item(choice_id.trim_prefix("reforge_item:"))
		return true
	if choice_id.begins_with("reforge_line:"):
		var parts := choice_id.split(":")
		var item_id := parts[1]
		if not game.player.can_pay(cost(item_id)):
			game.hud.show_message("Нужно: %s." % game.borin.cost_text(cost(item_id)), 3.0)
			_open_item(item_id)
			return true
		var fresh := reforge(item_id, int(parts[2]))
		if fresh.is_empty():
			open_list()
			return true
		GameAudio.play("hit", -2.0, 0.2)
		game.shake(2.0, 0.15)
		game._show_dialogue_choices("Борин, кузнец", "Было: %s. Стало: %s." % [line_of(pending["old"]), line_of(fresh)], [
			{"id": "reforge_keep", "label": "Оставить новое — %s" % line_of(fresh)},
			{"id": "reforge_revert", "label": "Вернуть старое — %s" % line_of(pending["old"])}])
		return true
	if choice_id.begins_with("trophy_forge:"):
		var kind := choice_id.trim_prefix("trophy_forge:")
		if forge_trophy(kind):
			var item_id := SignatureGear.trophy_of(kind)
			GameAudio.play("hit", -2.0, 0.2)
			game.hud.show_title_card("Трофей выкован", 2.2)
			game._show_dialogue("Борин, кузнец", "Готово: %s. Особое: %s" % [game.player.get_item_name(item_id), SignatureGear.effect_text(item_id)])
		else:
			game.hud.show_message("Нужно: %s." % game.borin.cost_text(TROPHY_COST), 3.0)
			open_trophies()
		return true
	return false
