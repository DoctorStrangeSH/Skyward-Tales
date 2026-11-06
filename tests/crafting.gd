extends SceneTree

## Gathering and crafting: resource points give materials and rest on the
## play clock, Lira's table brews potions, the kitchen opens with Martha's
## house, food gives timed buffs, recipe scrolls teach recipes, houses need
## wood and stone. Everything survives saving.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("CRAFTING TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _node(kind: String) -> GatherNode:
	for node in game.get_children():
		if node is GatherNode and node.kind == kind and node.available:
			return node
	return null

func _station(id: String) -> CraftStation:
	for node in game.get_children():
		if node is CraftStation and node.station_id == id:
			return node
	return null

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player

	# Gathering.
	var log := _node("wood")
	if not _verify(log != null and _node("stone") != null and _node("healroot") != null and _node("bluebell") != null, "the first world has logs, rocks and herbs"):
		return
	log.interact()
	var wood := int(hero.inventory.get("wood", 0))
	if not _verify(wood >= 2 and not log.available, "a log gives wood and rests"):
		return
	log.interact()
	if not _verify(int(hero.inventory.get("wood", 0)) == wood, "a resting log gives nothing"):
		return
	game.crafting.tick(300.0)
	game.crafting.refresh_nodes()
	if not _verify(log.available, "the log grows back with time"):
		return

	# Alchemy at Lira's table: two healroots -> two health potions.
	hero.add_item("healroot", 2)
	var potions := int(hero.inventory.get("health_potion", 0))
	_station("alchemy").interact()
	game._on_dialogue_choice_selected("craft:brew_health")
	if not _verify(int(hero.inventory.get("health_potion", 0)) == potions + 2 and not hero.inventory.has("healroot"), "the table brews potions"):
		return
	if not _verify(game.hud.crafting_visible, "the station stays open for more crafting"):
		return
	game._on_dialogue_choice_selected("craft_close")

	# The kitchen needs a cook.
	hero.add_item("fish", 2)
	hero.add_item("healroot", 1)
	_station("kitchen").interact()
	game._on_dialogue_choice_selected("craft:cook_fish_stew")
	if not _verify(not hero.inventory.has("fish_stew"), "no cook, no kitchen"):
		return
	game.hud.close_dialogue()
	game.settlement.invite("cook")
	hero.gold = 500
	hero.add_item("wood", 1)
	if not _verify(not game.settlement.build("cook"), "a house needs wood and stone"):
		return
	hero.add_item("wood", 20)
	hero.add_item("stone", 10)
	if not _verify(game.settlement.build("cook"), "with materials the house goes up"):
		return
	_station("kitchen").interact()
	game._on_dialogue_choice_selected("craft:cook_fish_stew")
	game._on_dialogue_choice_selected("craft_close")
	if not _verify(int(hero.inventory.get("fish_stew", 0)) == 1, "Martha's kitchen cooks"):
		return

	# Food buffs.
	hero.health = 20
	game._on_inventory_use("fish_stew")
	if not _verify(hero.health == 60 and hero.buffs.has("regen"), "stew heals and keeps healing"):
		return
	hero.add_item("power_elixir", 1)
	var before := hero.get_spell_power_multiplier()
	game._on_inventory_use("power_elixir")
	if not _verify(is_equal_approx(hero.get_spell_power_multiplier(), before * 1.2), "the elixir strengthens spells"):
		return

	# Recipe scrolls teach, then the recipe appears at its station.
	if not _verify(not game.crafting.recipes_for("kitchen").has("cook_hearty_stew"), "the hearty stew is unknown"):
		return
	hero.add_item("recipe_hearty_stew")
	if not _verify(hero.learned_recipes.has("recipe_hearty_stew") and not hero.inventory.has("recipe_hearty_stew"), "the scroll is learned, not stored"):
		return
	if not _verify(game.crafting.recipes_for("kitchen").has("cook_hearty_stew"), "the kitchen offers the new recipe"):
		return

	log.interact()
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	if not _verify(restored.player.learned_recipes.has("recipe_hearty_stew") and not restored.crafting.is_ready(log.key), "recipes and resting logs are saved"):
		return
	print("CRAFTING OK: gathering, regrowth, alchemy, kitchen with cook, house materials, food buffs, recipe scrolls, save/load")
	quit(0)
