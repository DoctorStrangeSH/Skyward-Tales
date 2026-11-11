extends RefCounted
class_name Settlement

## The village grows: people met around the world (data/settlement.json) can
## be invited home; at the settlement board the hero builds them a house on a
## free plot. Each settler then offers a service: cheaper building, a meal
## that restores everything, or potions — gifts refresh after every completed
## quest. State: recruited settlers, which plot holds whose house, gifts.

const DATA_PATH := "res://data/settlement.json"

var game: SkywardGame
var data: Dictionary = {}
var recruited: Dictionary = {}     # settler id -> true
var homes: Dictionary = {}         # plot id -> settler id
var gift_marks: Dictionary = {}    # settler id -> completed quests when last served
var buildings: Dictionary = {}     # building id -> level (farm, …)

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed

func settlers() -> Dictionary:
	return data.get("settlers", {})

func settler(id: String) -> Dictionary:
	return settlers().get(id, {})

func village_region() -> String:
	return str(data.get("region", "greenreach"))

func home_of(id: String) -> String:
	for plot_id in homes:
		if homes[plot_id] == id:
			return str(plot_id)
	return ""

func plot(plot_id: String) -> Dictionary:
	for entry in data.get("plots", []):
		if str(entry.get("id", "")) == plot_id:
			return entry
	return {}

func free_plots() -> Array[String]:
	var result: Array[String] = []
	for entry in data.get("plots", []):
		if not homes.has(str(entry.get("id", ""))):
			result.append(str(entry.get("id", "")))
	return result

func homeless() -> Array[String]:
	var result: Array[String] = []
	for id in settlers():
		if recruited.has(id) and home_of(str(id)).is_empty():
			result.append(str(id))
	return result

func house_cost(id: String) -> int:
	return int(round(float(settler(id).get("cost", 60)) * _discount()))

func _discount() -> float:
	var factor := 1.0
	for plot_id in homes:
		var service: Dictionary = settler(str(homes[plot_id])).get("service", {})
		if str(service.get("type", "")) == "discount":
			factor *= 1.0 - float(service.get("value", 0.0))
	return factor

## Wood and stone a house needs (after the woodcutter's discount).
func house_materials(id: String) -> Dictionary:
	var result := {}
	var mats: Dictionary = settler(id).get("materials", {})
	for item_id in mats:
		result[item_id] = maxi(1, int(round(float(mats[item_id]) * _discount())))
	return result

func _materials_text(id: String) -> String:
	var parts: Array[String] = []
	var mats := house_materials(id)
	for item_id in mats:
		parts.append("%s %d/%d" % [game.player.get_item_name(item_id), int(game.player.inventory.get(item_id, 0)), int(mats[item_id])])
	return ", ".join(parts)

func _completed_quests() -> int:
	var total := 0
	for quest_id in game.quests.states:
		if game.quests.is_completed(str(quest_id)):
			total += 1
	return total

# --- World objects -------------------------------------------------------

## NPC entries this region should spawn: settlers waiting where they were
## found, and (in the village) settlers at their house or by the board.
func npcs_for(region_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if region_id == village_region() and game.buildings != null:
		result.append_array(game.buildings.npcs())
	var waiting_index := 0
	for id in settlers():
		var entry: Dictionary = settlers()[id]
		var npc_id := "settler_" + str(id)
		if not recruited.has(id):
			var found: Dictionary = entry.get("found", {})
			if str(found.get("region", "")) == region_id:
				result.append({"id": npc_id, "name": entry.get("name", id), "position": found.get("position", [0, 0])})
		elif region_id == village_region():
			var plot_id := home_of(str(id))
			var spot := Vector2.ZERO
			if not plot_id.is_empty():
				var p: Array = plot(plot_id).get("position", [0, 0])
				spot = Vector2(float(p[0]), float(p[1]) + 18.0)
			else:
				var b: Array = data.get("board", {}).get("position", [0, 0])
				spot = Vector2(float(b[0]) - 30.0 + waiting_index * 20.0, float(b[1]) + 22.0)
				waiting_index += 1
			result.append({"id": npc_id, "name": entry.get("name", id), "position": [spot.x, spot.y]})
	return result

func has_settler_npc(npc_id: String) -> bool:
	return npc_id.begins_with("settler_") and settlers().has(npc_id.trim_prefix("settler_"))

# --- Conversations -------------------------------------------------------

func marker_for(npc_id: String) -> String:
	var id := npc_id.trim_prefix("settler_")
	if not recruited.has(id):
		return "quest"
	if not home_of(id).is_empty() and gift_ready(id):
		return "ready"
	return ""

func gift_ready(id: String) -> bool:
	var service: Dictionary = settler(id).get("service", {})
	if not str(service.get("type", "")) in ["heal", "items"]:
		return false
	return _completed_quests() > int(gift_marks.get(id, -1))

func talk(npc_id: String) -> void:
	var id := npc_id.trim_prefix("settler_")
	var entry := settler(id)
	var speaker := str(entry.get("name", id))
	if not recruited.has(id):
		var choices: Array[Dictionary] = [
			{"id": "settle_invite:" + id, "label": "Пойдём в нашу деревню"},
			{"id": "settle_later", "label": "Подумаю"},
		]
		game._show_dialogue_choices(speaker, StoryText.format(str(entry.get("recruit", ""))), choices)
		return
	if home_of(id).is_empty():
		game._show_dialogue(speaker, StoryText.format(str(entry.get("waiting", ""))))
		return
	if gift_ready(id):
		_serve(id)
		return
	var service: Dictionary = entry.get("service", {})
	game._show_dialogue(speaker, StoryText.format(str(entry.get("home", ""))) + "\n" + str(service.get("label", "")))

func _serve(id: String) -> void:
	var entry := settler(id)
	var service: Dictionary = entry.get("service", {})
	gift_marks[id] = _completed_quests()
	match str(service.get("type", "")):
		"heal":
			game.player.health = game.player.max_health
			game.player.mana = game.player.max_mana
			game.player.stats_changed.emit()
			Vfx.sparkle(game, game.player.global_position)
			game._show_dialogue(str(entry.get("name", id)), "Горячая похлёбка! Ешь, набирайся сил. (Здоровье и мана восстановлены)")
		"items":
			var summary := game.dialogues._grant_reward({"items": service.get("items", [])})
			game._show_dialogue(str(entry.get("name", id)), "Вот, держи улов%s." % summary)
	GameAudio.play("pickup", -3.0, 0.0)
	game.update_npc_markers()

func handle_choice(choice_id: String) -> bool:
	if choice_id == "settle_later":
		game.dialogues._close()
		return true
	if choice_id.begins_with("settle_invite:"):
		game.dialogues._close()
		invite(choice_id.trim_prefix("settle_invite:"))
		return true
	if choice_id.begins_with("settle_upgrade:"):
		game.dialogues._close()
		upgrade(choice_id.trim_prefix("settle_upgrade:"))
		return true
	if choice_id.begins_with("settle_build:"):
		game.dialogues._close()
		build(choice_id.trim_prefix("settle_build:"))
		return true
	return false

## The settler packs up and heads for the village.
func invite(id: String) -> bool:
	if recruited.has(id) or not settlers().has(id):
		return false
	recruited[id] = true
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "settler_" + id:
			Vfx.sparkle(game, node.global_position)
			node.queue_free()
	game.hud.show_message("%s идёт в деревню. Постройте дом у доски поселения." % str(settler(id).get("name", id)).get_slice(",", 0), 3.5)
	GameAudio.play("quest", -4.0, 0.0)
	game.request_autosave()
	return true

# --- Buildings with levels (data: buildings) -------------------------------

func building_level(id: String) -> int:
	return int(buildings.get(id, 0))

func building_info(id: String) -> Dictionary:
	return data.get("buildings", {}).get(id, {})

## The next level's needs, or {} when the building is complete.
func next_level(id: String) -> Dictionary:
	var levels: Array = building_info(id).get("levels", [])
	var current := building_level(id)
	return levels[current] if current < levels.size() else {}

func upgrade_cost(id: String) -> int:
	return int(round(float(next_level(id).get("gold", 0)) * _discount()))

func upgrade_materials(id: String) -> Dictionary:
	var result := {}
	var mats: Dictionary = next_level(id).get("materials", {})
	for item_id in mats:
		result[item_id] = maxi(1, int(round(float(mats[item_id]) * _discount())))
	return result

func upgrade(id: String) -> bool:
	var step := next_level(id)
	if step.is_empty():
		return false
	var cost := upgrade_cost(id)
	if game.player.gold < cost:
		game.hud.show_message("Не хватает золота: нужно %d." % cost, 2.5)
		return false
	var mats := upgrade_materials(id)
	for item_id in mats:
		if int(game.player.inventory.get(item_id, 0)) < int(mats[item_id]):
			game.pin.pin("building", id)
			game.hud.show_message("Не хватает: %s (нужно %d). Список закреплён на экране." % [game.player.get_item_name(item_id), int(mats[item_id])], 3.5)
			return false
	for item_id in mats:
		game.player.remove_item(item_id, int(mats[item_id]))
	game.player.gold -= cost
	game.player.stats_changed.emit()
	buildings[id] = building_level(id) + 1
	var name := str(building_info(id).get("name", id))
	game.hud.show_title_card("%s · ур. %d" % [name, building_level(id)], 2.2)
	game.hud.show_message(str(step.get("text", "")), 4.0)
	GameAudio.play("chest", -2.0, 0.0)
	game.achievements.set_max("buildings", _total_levels())
	game.on_building_upgraded(id)
	game.request_autosave()
	return true

func _total_levels() -> int:
	var total := 0
	for id in buildings:
		total += int(buildings[id])
	return total

func _building_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for id in data.get("buildings", {}):
		var step := next_level(str(id))
		if step.is_empty():
			continue
		var parts: Array[String] = []
		var mats := upgrade_materials(str(id))
		for item_id in mats:
			parts.append("%s %d/%d" % [game.player.get_item_name(item_id), int(game.player.inventory.get(item_id, 0)), int(mats[item_id])])
		var verb := "Построить" if building_level(str(id)) == 0 else "Улучшить"
		choices.append({"id": "settle_upgrade:" + str(id), "label": "%s: %s (ур. %d) — %d золота%s" % [verb, str(building_info(str(id)).get("name", id)), building_level(str(id)) + 1, upgrade_cost(str(id)), (", " + ", ".join(parts)) if not parts.is_empty() else ""]})
	return choices

# --- Building -------------------------------------------------------------

func open_board() -> void:
	var waiting := homeless()
	var plots := free_plots()
	var lines := "Жители: %d · свободных участков: %d" % [homes.size(), plots.size()]
	var choices: Array[Dictionary] = []
	for id in waiting:
		if plots.is_empty():
			break
		var name := str(settler(id).get("name", id)).get_slice(",", 0)
		var mats := _materials_text(id)
		choices.append({"id": "settle_build:" + id, "label": "Дом для: %s — %d золота%s" % [name, house_cost(id), (", " + mats) if not mats.is_empty() else ""]})
	if choices.is_empty():
		if waiting.is_empty():
			lines += "\nВстречайте людей в других землях и зовите их сюда — для каждого найдётся участок."
		else:
			lines += "\nВсе участки заняты."
	for id in buildings:
		lines += "\n%s — ур. %d" % [str(building_info(str(id)).get("name", id)), int(buildings[id])]
	choices.append_array(_building_choices())
	if choices.is_empty():
		game._show_dialogue("Доска поселения", lines)
		return
	choices.append({"id": "settle_later", "label": "Позже"})
	game._show_dialogue_choices("Доска поселения", lines, choices)

func build(id: String) -> bool:
	var plots := free_plots()
	if plots.is_empty() or not recruited.has(id) or not home_of(id).is_empty():
		return false
	var cost := house_cost(id)
	if game.player.gold < cost:
		game.hud.show_message("Не хватает золота: нужно %d." % cost, 2.5)
		return false
	var mats := house_materials(id)
	for item_id in mats:
		if int(game.player.inventory.get(item_id, 0)) < int(mats[item_id]):
			game.pin.pin("house", id)
			game.hud.show_message("Не хватает: %s (нужно %d). Список закреплён на экране." % [game.player.get_item_name(item_id), int(mats[item_id])], 3.5)
			return false
	for item_id in mats:
		game.player.remove_item(item_id, int(mats[item_id]))
	game.player.gold -= cost
	game.player.stats_changed.emit()
	homes[plots[0]] = id
	GameAudio.play("chest", -2.0, 0.0)
	game.hud.show_message("Построен дом: %s въезжает!" % str(settler(id).get("name", id)).get_slice(",", 0), 3.5)
	if game.current_region == village_region():
		game.refresh_settlement()
	game.request_autosave()
	return true

func make_snapshot() -> Dictionary:
	return {"recruited": recruited.duplicate(), "homes": homes.duplicate(), "gifts": gift_marks.duplicate(), "buildings": buildings.duplicate()}

func restore_snapshot(snapshot: Variant) -> void:
	recruited = {}
	homes = {}
	gift_marks = {}
	buildings = {}
	if not snapshot is Dictionary:
		return
	if snapshot.get("buildings", {}) is Dictionary:
		for id in snapshot["buildings"]:
			buildings[str(id)] = int(snapshot["buildings"][id])
	for id in snapshot.get("recruited", {}):
		if settlers().has(id):
			recruited[id] = true
	for plot_id in snapshot.get("homes", {}):
		var id := str(snapshot["homes"][plot_id])
		if settlers().has(id) and not plot(str(plot_id)).is_empty():
			homes[str(plot_id)] = id
	for id in snapshot.get("gifts", {}):
		gift_marks[str(id)] = int(snapshot["gifts"][id])
