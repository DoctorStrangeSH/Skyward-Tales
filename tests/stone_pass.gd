extends SceneTree

## Stone Pass: up from the crystal caves, Gunhild's chain (golems, coal,
## the Mountain Giant), her forge opens after the golems and forges steel,
## recipe rewards unlock sky-steel; iron veins regrow.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STONE PASS TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _all(script_name: String) -> Array:
	var found := []
	for node in game.get_children():
		if not node.is_queued_for_deletion() and node.get_script() != null and node.get_script().get_global_name() == script_name:
			found.append(node)
	return found

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.guardian_defeated = true
	game._set_region("crystal_caves", Vector2(190, 140), false)
	game._on_region_travel("stone_pass", Vector2(800, 980))
	await process_frame
	if not _verify(game.current_region == "stone_pass", "the caves lead up to the Stone Pass"):
		return
	var golems := _all("StoneGolem")
	if not _verify(golems.size() == 5 and golems[0].max_health == 90 and _all("MountainGiant").is_empty(), "golems on the roads, the giant waits"):
		return
	var hero := game.player
	game.crafting.open("forge_steel")
	if not _verify(game.crafting._open_station.is_empty(), "the master's forge is closed to strangers"):
		return
	game.hud.close_dialogue()
	game.givers.talk("smith_master")
	game._on_dialogue_choice_selected("giver_accept:pass_golems")
	for golem in golems.slice(0, 4):
		golem.take_damage(9999)
		await process_frame
	game.givers.talk("smith_master")
	game.hud.close_dialogue()
	if not _verify(game.quests.is_completed("pass_golems") and int(hero.inventory.get("iron_ore", 0)) >= 4, "golems broken, ore paid"):
		return
	hero.add_item("ironbound_staff")
	hero.add_item("wood", 2)
	game.crafting.open("forge_steel")
	game._on_dialogue_choice_selected("craft:forge_steel_staff")
	game._on_dialogue_choice_selected("craft_close")
	if not _verify(int(hero.inventory.get("steel_staff", 0)) == 1, "the forge makes a steel staff"):
		return
	if not _verify(not game.crafting.recipes_for("forge_steel").has("forge_skysteel_staff"), "sky-steel is still a secret"):
		return
	game.givers.talk("smith_master")
	game._on_dialogue_choice_selected("giver_accept:pass_coal")
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "coal_sack":
			game._on_herb_interacted(node)
	game.givers.talk("smith_master")
	game.hud.close_dialogue()
	if not _verify(hero.learned_recipes.has("recipe_steel_mail"), "coal earns the steel mail recipe"):
		return
	game.givers.talk("smith_master")
	game._on_dialogue_choice_selected("giver_accept:pass_giant")
	var giants := _all("MountainGiant")
	if not _verify(giants.size() == 1 and SkywardGame.enemy_kind(giants[0]) == "giant", "the giant rises"):
		return
	giants[0].take_damage(giants[0].max_health / 2 + 5)
	await process_frame
	if not _verify(_all("StoneGolem").size() == 3, "enraged, he wakes two golems"):
		return
	giants[0].take_damage(9999)
	await process_frame
	game.givers.talk("smith_master")
	game.hud.close_dialogue()
	if not _verify(hero.learned_recipes.has("recipe_skysteel") and game.crafting.recipes_for("forge_steel").has("forge_skysteel_staff"), "sky-steel recipes learned"):
		return
	var vein: GatherNode = null
	for node in game.get_children():
		if node is GatherNode and node.kind == "iron":
			vein = node
	vein.interact()
	if not _verify(not vein.available and int(hero.inventory.get("iron_ore", 0)) >= 1, "iron veins can be mined"):
		return
	print("STONE PASS OK: road, golems, closed forge, steel staff, coal, giant, sky-steel recipes, iron veins")
	quit(0)
