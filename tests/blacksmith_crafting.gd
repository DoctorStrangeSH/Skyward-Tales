extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("BLACKSMITH CRAFTING FAILED: " + reason)
		quit(1)
		return false
	return true

func _new_game() -> Node2D:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	return game

func _run() -> void:
	var game := _new_game()
	await process_frame
	var blacksmith_found := false
	for actor in game.get_children():
		if actor is WorldNpc and actor.display_name == "Кузнец Борин":
			blacksmith_found = true
			break
	if not _verify(blacksmith_found, "Borin is present in the village"):
		return
	var unavailable: Dictionary = game.crafting_service.get_recipe_status(game.player, "reinforce_wolfskin_mantle")
	if not _verify(not bool(unavailable.get("success", false)), "recipe is unavailable without materials"):
		return
	game.player.add_item("wolfskin_mantle")
	game.player.add_item("wolf_pelt", 2)
	game.player.add_gold(40)
	game._on_blacksmith_interacted(null)
	if not _verify(game.hud.dialogue_choices_container.get_child_count() >= 2, "blacksmith offers the available recipe"):
		return
	game._on_dialogue_choice_selected("blacksmith_craft:reinforce_mantle")
	if not _verify(int(game.player.inventory.get("wolfskin_mantle", 0)) == 0, "base mantle is consumed"):
		return
	if not _verify(int(game.player.inventory.get("wolf_pelt", 0)) == 0, "two wolf pelts are consumed"):
		return
	if not _verify(game.player.gold == 10, "thirty gold are consumed"):
		return
	if not _verify(int(game.player.inventory.get("reinforced_wolf_mantle", 0)) == 1, "reinforced mantle is crafted"):
		return
	if not _verify(game.player.equip_item("reinforced_wolf_mantle"), "reinforced mantle can be equipped"):
		return
	if not _verify(game.player.get_armor() == 9, "reinforced mantle grants nine armor"):
		return
	var duplicate: Dictionary = game.crafting_service.get_recipe_status(game.player, "reinforce_wolfskin_mantle")
	if not _verify(not bool(duplicate.get("success", false)), "unique output cannot be crafted twice"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	var restored := _new_game()
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "crafted equipment survives save/load"):
		return
	if not _verify(restored.player.get_armor() == 9, "reinforced armor restores correctly"):
		return
	print("BLACKSMITH CRAFTING OK: NPC, recipe validation, exact costs, unique output, equipment and save/load")
	quit(0)
