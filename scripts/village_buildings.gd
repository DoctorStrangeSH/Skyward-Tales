extends RefCounted
class_name VillageBuildings

## Services of the village buildings (settlement.json → buildings).
## Tavern (Greta): food, a treasure map with a rumor; level 2 — hire a
##   sellsword for a day (world state "mercenary").
## Library (Olwin): reads ancient tomes — each gives a skill point; level 2 —
##   the star atlas marks every chest on the maps of visited lands.
## Buildings stand on their spots once built; keepers stand at the door.

const TAVERN := "tavern"
const LIBRARY := "library"
const FOOD := {"bread": 14, "fish_stew": 22, "berry_pie": 45}
const MAP_PRICE := 30
const MERC_PRICE := 120
const TOME := "ancient_tome"

var game: SkywardGame
var tomes_read: int = 0

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func level(id: String) -> int:
	return game.settlement.building_level(id)

func info(id: String) -> Dictionary:
	return game.settlement.building_info(id)

## Buildings and keepers for the village.
func spawn() -> void:
	for id in game.settlement.data.get("buildings", {}):
		var data: Dictionary = info(str(id))
		if not data.has("position") or level(str(id)) <= 0:
			continue
		var at := SkywardGame._vec(data.get("position"))
		var object := SettlementObject.new()
		object.kind = "house"
		object.art = "%s_%d" % [str(data.get("art", "village_house_small")), mini(level(str(id)), 2)]
		object.wall_width = float(data.get("wall", 56))
		game.add_child(object)
		object.global_position = at

## NPC entries (keepers) for the village region.
func npcs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in game.settlement.data.get("buildings", {}):
		var data: Dictionary = info(str(id))
		var keeper: Dictionary = data.get("keeper", {})
		if keeper.is_empty() or level(str(id)) <= 0:
			continue
		var at := SkywardGame._vec(data.get("position")) + SkywardGame._vec(keeper.get("offset", [0, 16]))
		result.append({"id": str(keeper["id"]), "name": str(keeper["name"]), "position": [at.x, at.y]})
	return result

# --- Tavern ---------------------------------------------------------------

func talk_tavern() -> void:
	var choices: Array[Dictionary] = []
	for item_id in FOOD:
		choices.append({"id": "tavern_buy:" + item_id, "label": "%s — %d золота" % [game.player.get_item_name(item_id), int(FOOD[item_id])]})
	choices.append({"id": "tavern_map", "label": "Карта сокровищ и свежий слух — %d золота" % MAP_PRICE})
	if level(TAVERN) >= 2:
		if game.world_state.has("mercenary"):
			choices.append({"id": "tavern_close", "label": "Наёмник уже с тобой (ещё %d дн.)" % game.world_state.days_left("mercenary")})
		else:
			choices.append({"id": "tavern_merc", "label": "Нанять наёмника на день — %d золота" % MERC_PRICE})
	choices.append({"id": "tavern_close", "label": "Уйти"})
	game._show_dialogue_choices("Грета, хозяйка таверны", StoryText.format("Заходи, {hero}! Горячая еда, холодный эль и новости со всех островов."), choices)

func _buy(price: int) -> bool:
	if game.player.gold < price:
		game.hud.show_message("Не хватает золота: нужно %d." % price, 2.5)
		return false
	game.player.add_gold(-price)
	return true

func hire_mercenary() -> bool:
	if level(TAVERN) < 2 or game.world_state.has("mercenary") or not _buy(MERC_PRICE):
		return false
	game.world_state.set_state("mercenary", 1.0)
	spawn_mercenary()
	game.hud.show_message("Наёмник Кай пойдёт с вами весь день.", 3.0)
	return true

## The sellsword follows the hero from land to land while hired.
func spawn_mercenary() -> void:
	if not game.world_state.has("mercenary"):
		return
	for node in game.get_children():
		if node is Mercenary and not node.is_queued_for_deletion():
			# Arrives in the new land together with the hero.
			node.global_position = game.player.global_position + Vector2(-24, 12)
			return
	var merc := Mercenary.new()
	merc.game = game
	game.add_child(merc)
	merc.global_position = game.player.global_position + Vector2(-24, 12)

# --- Library --------------------------------------------------------------

func talk_library() -> void:
	var tomes := int(game.player.inventory.get(TOME, 0))
	var choices: Array[Dictionary] = []
	if tomes > 0:
		choices.append({"id": "library_read", "label": "Прочитать древний том (есть: %d) → очко навыков" % tomes})
	choices.append({"id": "library_close", "label": "Уйти"})
	var text := "Прочитано томов: %d. Древние тома находят у легенд, боссов и в золотых сундуках." % tomes_read
	if level(LIBRARY) >= 2:
		text += "\nЗвёздный купол показывает сундуки на картах посещённых земель."
	game._show_dialogue_choices("Олвин, хранитель книг", text, choices)

func read_tome() -> bool:
	if level(LIBRARY) < 1 or not game.player.remove_item(TOME, 1):
		return false
	tomes_read += 1
	game.player.bonus_skill_points += 1
	game.player.stats_changed.emit()
	game.achievements.add("tomes")
	game.hud.show_title_card("Знание Хранителей", 2.0)
	game.hud.show_message("Олвин читает том вслух… +1 очко навыков (T — дерево навыков).", 3.5)
	GameAudio.play("level_up", -4.0, 0.0)
	game.request_autosave()
	return true

## Star atlas: every chest of the land goes on its map.
func reveal_chests() -> void:
	if level(LIBRARY) < 2:
		return
	var markers: Dictionary = game.discovered_landmarks.get(game.current_region, {})
	for node in game.get_children():
		if node is TreasureChest and not node.is_queued_for_deletion():
			var key := "chest_%d_%d" % [int(node.global_position.x), int(node.global_position.y)]
			if not markers.has(key):
				markers[key] = {"position": [node.global_position.x, node.global_position.y], "kind": "chest"}
	game.discovered_landmarks[game.current_region] = markers

func handle_choice(choice_id: String) -> bool:
	if choice_id in ["tavern_close", "library_close"]:
		game.dialogues._close()
		return true
	if choice_id.begins_with("tavern_buy:"):
		var item_id := choice_id.trim_prefix("tavern_buy:")
		if FOOD.has(item_id) and _buy(int(FOOD[item_id])):
			game.player.add_item(item_id, 1)
			game.hud.show_message("Куплено: %s." % game.player.get_item_name(item_id), 2.0)
		talk_tavern()
		return true
	if choice_id == "tavern_map":
		if _buy(MAP_PRICE):
			game.player.add_item(TreasureHunt.MAP_ITEM, 1)
			game._show_dialogue("Грета, хозяйка таверны", "Один капитан оставил эту карту в уплату за ужин. А ещё говорят… " + game.village.rumor())
		return true
	if choice_id == "tavern_merc":
		game.dialogues._close()
		hire_mercenary()
		return true
	if choice_id == "library_read":
		read_tome()
		talk_library()
		return true
	return false

func make_snapshot() -> Dictionary:
	return {"tomes_read": tomes_read}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary:
		tomes_read = int(data.get("tomes_read", 0))
