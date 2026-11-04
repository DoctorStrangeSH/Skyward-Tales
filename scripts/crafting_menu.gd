extends RefCounted
class_name CraftingMenu

## Gathering and station crafting. Gathering nodes come from regions.json
## "gather" (kinds in data/gathering.json) and rest after use on the play
## clock; stations list the recipes the hero knows for them.

const DATA_PATH := "res://data/gathering.json"

var game: SkywardGame
var data: Dictionary = {}
var cooldowns: Dictionary = {}   # node key -> play time when it is ready
var play_time: float = 0.0
var _open_station: String = ""

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed

func tick(delta: float) -> void:
	play_time += delta

func kind(kind_id: String) -> Dictionary:
	return data.get("kinds", {}).get(kind_id, {})

func is_ready(key: String) -> bool:
	return play_time >= float(cooldowns.get(key, 0.0))

# --- Gathering -------------------------------------------------------------

func gather(node: GatherNode) -> bool:
	if not is_ready(node.key):
		var left := int(ceil(float(cooldowns[node.key]) - play_time))
		game.hud.show_message("%s: вырастет снова через %d с." % [node.display_name, left], 2.0)
		return false
	var info := kind(node.kind)
	var amount_range: Array = info.get("amount", [1, 1])
	var amount := game.loot_rng.randi_range(int(amount_range[0]), int(amount_range[1]))
	var item_id := str(info.get("item", node.kind))
	game.player.add_item(item_id, amount)
	cooldowns[node.key] = play_time + float(info.get("respawn", 200))
	node.set_ready(false)
	Vfx.sparkle(game, node.global_position)
	GameAudio.play("pickup", -5.0, 0.08)
	game.hud.show_message("+%d %s" % [amount, game.player.get_item_name(item_id)], 1.6)
	return true

func refresh_nodes() -> void:
	for node in game.get_children():
		if node is GatherNode and not node.available and is_ready(node.key):
			node.set_ready(true)

# --- Stations --------------------------------------------------------------

func station(station_id: String) -> Dictionary:
	return data.get("stations", {}).get(station_id, {})

func recipes_for(station_id: String) -> Array[String]:
	var result: Array[String] = []
	for recipe_id in game.crafting_service.recipes:
		var recipe: Dictionary = game.crafting_service.recipes[recipe_id]
		if str(recipe.get("station", "")) != station_id:
			continue
		var needs := str(recipe.get("requires_recipe", ""))
		if not needs.is_empty() and not game.player.learned_recipes.has(needs):
			continue
		result.append(str(recipe_id))
	return result

func _ingredients_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for ingredient in recipe.get("ingredients", []):
		var item_id := str(ingredient.get("item_id", ""))
		parts.append("%s %d/%d" % [game.player.get_item_name(item_id), int(game.player.inventory.get(item_id, 0)), int(ingredient.get("amount", 1))])
	return ", ".join(parts)

func open(station_id: String) -> void:
	var info := station(station_id)
	var name := str(info.get("name", station_id))
	var settler_needed := str(info.get("needs_settler", ""))
	var quest_needed := str(info.get("needs_quest", ""))
	if (not settler_needed.is_empty() and game.settlement.home_of(settler_needed).is_empty()) or (not quest_needed.is_empty() and not game.quests.is_completed(quest_needed)):
		_open_station = ""
		game._show_dialogue(name, str(info.get("locked", "Пока здесь некому работать.")))
		return
	_open_station = station_id
	var choices: Array[Dictionary] = []
	for recipe_id in recipes_for(station_id):
		var recipe: Dictionary = game.crafting_service.recipes[recipe_id]
		var ok := bool(game.crafting_service.get_recipe_status(game.player, recipe_id).get("success", false))
		choices.append({"id": "craft:" + recipe_id, "label": "%s%s — %s" % ["✓ " if ok else "", str(recipe.get("name", recipe_id)), _ingredients_text(recipe)]})
	choices.append({"id": "craft_close", "label": "Закрыть"})
	var hint := "Выберите, что приготовить." if station_id == "kitchen" else "Выберите, что изготовить."
	game._show_dialogue_choices(name, hint + " Новые рецепты находят в сундуках и получают в награду.", choices)

func handle_choice(choice_id: String) -> bool:
	if choice_id == "craft_close":
		_open_station = ""
		game.dialogues._close()
		return true
	if not choice_id.begins_with("craft:"):
		return false
	var recipe_id := choice_id.trim_prefix("craft:")
	# Only what the open station offers can be made.
	if _open_station.is_empty() or not recipes_for(_open_station).has(recipe_id):
		return true
	var result := game.crafting_service.craft(game.player, recipe_id)
	game.hud.show_message(str(result.get("message", "")), 2.2)
	if bool(result.get("success", false)):
		GameAudio.play("chest", -6.0, 0.05)
	# Stay at the station so several things can be made in a row.
	var station_id := _open_station
	game.dialogues._close()
	if not station_id.is_empty():
		open(station_id)
	return true

func make_snapshot() -> Dictionary:
	return {"play_time": play_time, "cooldowns": cooldowns.duplicate()}

func restore_snapshot(snapshot: Variant) -> void:
	cooldowns = {}
	play_time = 0.0
	if snapshot is Dictionary:
		play_time = float(snapshot.get("play_time", 0.0))
		var saved: Variant = snapshot.get("cooldowns", {})
		if saved is Dictionary:
			for key in saved:
				cooldowns[str(key)] = float(saved[key])
