extends Node
class_name Contracts

## Contract board (village "Доска заказов"): three random jobs at a time —
## hunts in lands the hero has visited and deliveries of materials. Up to two
## can be taken at once; a finished one pays gold and experience (sometimes
## a treasure map) and a new job takes its place.

const MAX_ACTIVE := 2
const REFRESH_COST := 15
const DELIVERY_POOL := [
	["wood", 1], ["stone", 1], ["healroot", 1], ["bluebell", 1], ["fish", 1], ["slime_gel", 1],
	["wolf_pelt", 2], ["wolf_fang", 2], ["iron_ore", 3], ["crab_shell", 4], ["toad_venom", 5],
	["bone", 3], ["bat_wing", 5], ["spirit_dust", 3], ["wind_essence", 7], ["shadow_essence", 9],
	["ash_hide", 10], ["obsidian_shard", 10],
]

var game: SkywardGame
var rng := RandomNumberGenerator.new()
var offers: Array = []
var active: Array = []
var completed: int = 0
var _serial: int = 0

func _ready() -> void:
	rng.randomize()

func _level() -> int:
	return maxi(1, game.player.level)

func _hunt_targets() -> Array:
	var targets: Array = []
	for region_id in RegionCatalog.ids():
		if not (game.visited_regions.has(region_id) or region_id == game.current_region):
			continue
		var kinds := {}
		for entry in RegionCatalog.get_region(region_id).get("enemies", []):
			var kind := str(entry.get("kind", ""))
			if entry.has("quest") or kind in SkywardGame.STORY_BOSSES or kind == "guardian":
				continue
			kinds[kind] = true
		for kind in kinds:
			targets.append([region_id, kind])
	return targets

func make_offer() -> Dictionary:
	_serial += 1
	var level := _level()
	var hunts := _hunt_targets()
	if not hunts.is_empty() and rng.randf() < 0.6:
		var pick: Array = hunts[rng.randi_range(0, hunts.size() - 1)]
		var region_level := RegionCatalog.level(str(pick[0]))
		var count := rng.randi_range(4, 8)
		var name := str(game.bestiary_entries.get(str(pick[1]), {}).get("name", pick[1]))
		return {"id": "c%d" % _serial, "type": "hunt", "kind": pick[1], "region": pick[0], "count": count, "progress": 0,
			"title": "Охота: %s ×%d (%s)" % [name, count, RegionCatalog.display_name(str(pick[0]))],
			"gold": count * (6 + region_level * 3), "xp": count * (8 + region_level * 5)}
	var pool := DELIVERY_POOL.filter(func(entry: Array) -> bool: return int(entry[1]) <= level + 1)
	var item: Array = pool[rng.randi_range(0, pool.size() - 1)]
	var count := rng.randi_range(3, 7)
	return {"id": "c%d" % _serial, "type": "deliver", "item": item[0], "count": count, "progress": 0,
		"title": "Поставка: %s ×%d" % [game.player.get_item_name(str(item[0])), count],
		"gold": count * (8 + int(item[1]) * 4), "xp": count * (6 + int(item[1]) * 4)}

func _fill_offers() -> void:
	while offers.size() < 3:
		offers.append(make_offer())

func is_ready(contract: Dictionary) -> bool:
	if contract.get("type", "") == "deliver":
		return int(game.player.inventory.get(str(contract.get("item", "")), 0)) >= int(contract.get("count", 1))
	return int(contract.get("progress", 0)) >= int(contract.get("count", 1))

func progress_text(contract: Dictionary) -> String:
	var have := int(game.player.inventory.get(str(contract.get("item", "")), 0)) if contract.get("type", "") == "deliver" else int(contract.get("progress", 0))
	return "%d/%d" % [mini(have, int(contract["count"])), int(contract["count"])]

## Hunts advance by kills of the right kind in the right land.
func on_kill(kind: String) -> void:
	for contract in active:
		if contract.get("type", "") == "hunt" and str(contract.get("kind", "")) == kind and str(contract.get("region", "")) == game.current_region:
			if int(contract["progress"]) < int(contract["count"]):
				contract["progress"] = int(contract["progress"]) + 1
				if is_ready(contract):
					game.hud.show_message("Заказ выполнен: %s. Сдайте на доске заказов." % str(contract["title"]), 3.0)

func open_board() -> void:
	_fill_offers()
	var lines := "Выполнено заказов: %d. Взято: %d из %d." % [completed, active.size(), MAX_ACTIVE]
	var choices: Array[Dictionary] = []
	for contract in active:
		if is_ready(contract):
			choices.append({"id": "contract_turn:" + str(contract["id"]), "label": "Сдать: %s → %d золота, %d опыта" % [contract["title"], contract["gold"], contract["xp"]]})
		else:
			lines += "\n• %s — %s" % [contract["title"], progress_text(contract)]
	if active.size() < MAX_ACTIVE:
		for index in offers.size():
			var offer: Dictionary = offers[index]
			choices.append({"id": "contract_take:%d" % index, "label": "Взять: %s — %d золота" % [offer["title"], offer["gold"]]})
	choices.append({"id": "contract_refresh", "label": "Новые заказы — %d золота" % REFRESH_COST})
	choices.append({"id": "contract_close", "label": "Позже"})
	game._show_dialogue_choices("Доска заказов", lines, choices)

func handle_choice(choice_id: String) -> bool:
	if choice_id.begins_with("contract_take:"):
		var index := int(choice_id.trim_prefix("contract_take:"))
		if index >= 0 and index < offers.size() and active.size() < MAX_ACTIVE:
			var contract: Dictionary = offers[index]
			offers.remove_at(index)
			active.append(contract)
			game.hud.show_message("Заказ взят: " + str(contract["title"]), 2.5)
		open_board()
		return true
	if choice_id.begins_with("contract_turn:"):
		turn_in(choice_id.trim_prefix("contract_turn:"))
		open_board()
		return true
	if choice_id == "contract_refresh":
		if game.player.gold >= REFRESH_COST:
			game.player.add_gold(-REFRESH_COST)
			offers.clear()
			_fill_offers()
		else:
			game.hud.show_message("Не хватает золота.", 2.0)
		open_board()
		return true
	if choice_id == "contract_close":
		game.hud.close_dialogue()
		game.player.set_physics_process(true)
		return true
	return false

func turn_in(contract_id: String) -> bool:
	for contract in active:
		if str(contract["id"]) != contract_id or not is_ready(contract):
			continue
		if contract.get("type", "") == "deliver":
			game.player.remove_item(str(contract["item"]), int(contract["count"]))
		active.erase(contract)
		completed += 1
		game.player.add_gold(int(contract["gold"]))
		game.player.add_experience(int(contract["xp"]))
		if rng.randf() < 0.25:
			game.player.add_item(TreasureHunt.MAP_ITEM)
			game.hud.show_message("Награда за заказ — и карта сокровищ в придачу!", 3.0)
		else:
			game.hud.show_message("Заказ сдан: +%d золота, +%d опыта." % [contract["gold"], contract["xp"]], 3.0)
		GameAudio.play("quest", -4.0, 0.0)
		return true
	return false

## Lines for the quest tracker.
func tracker_entries() -> Array:
	var result: Array = []
	for contract in active:
		var count := int(contract["count"])
		var have := mini(count, int(game.player.inventory.get(str(contract.get("item", "")), 0)) if contract.get("type", "") == "deliver" else int(contract["progress"]))
		result.append({"id": contract["id"], "title": str(contract["title"]).get_slice(" (", 0), "progress": have, "target": count, "main": false, "contract": true})
	return result

func make_snapshot() -> Dictionary:
	return {"offers": offers.duplicate(true), "active": active.duplicate(true), "completed": completed, "serial": _serial}

func restore_snapshot(data: Variant) -> void:
	if not data is Dictionary:
		return
	offers = (data.get("offers", []) as Array).duplicate(true) if data.get("offers", []) is Array else []
	active = (data.get("active", []) as Array).duplicate(true) if data.get("active", []) is Array else []
	completed = int(data.get("completed", 0))
	_serial = int(data.get("serial", 0))
