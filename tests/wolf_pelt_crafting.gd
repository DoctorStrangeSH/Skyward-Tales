extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("WOLF PELT CRAFTING FAILED: " + reason)
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
	game._on_wolf_defeated(8, Vector2(12, 20))
	var pelt_drop: WorldLoot = null
	for actor in game.get_children():
		if actor is WorldLoot and actor.item_id == "wolf_pelt":
			pelt_drop = actor
			break
	if not _verify(pelt_drop != null, "wolf defeat spawns a wolf pelt pickup"):
		return
	pelt_drop.interact()
	if not _verify(int(game.player.inventory.get("wolf_pelt", 0)) == 1, "collecting the drop adds one pelt to inventory"):
		return
	game.player.add_item("wolf_pelt", 2)
	game.quests.states["toren_wolf_hunt"]["completed"] = true
	game._on_hunter_interacted(null)
	if not _verify(game.hud.dialogue_choices_container.get_child_count() >= 2, "Toren offers crafting with three pelts"):
		return
	game._on_dialogue_choice_selected("hunter_craft:mantle")
	if not _verify(int(game.player.inventory.get("wolf_pelt", 0)) == 0, "craft consumes exactly three pelts"):
		return
	if not _verify(int(game.player.inventory.get("wolfskin_mantle", 0)) == 1, "craft grants one mantle"):
		return
	if not _verify(game.player.equip_item("wolfskin_mantle"), "crafted mantle can be equipped"):
		return
	if not _verify(game.player.get_armor() == 6, "crafted mantle grants six armor"):
		return
	game.player.add_item("wolf_pelt", 3)
	game._on_hunter_interacted(null)
	if not _verify(game.hud.dialogue_choices_container.get_child_count() == 0, "equipped mantle cannot be crafted a second time"):
		return
	if not _verify(not game.player.remove_item("wolf_pelt", 4), "cannot remove more materials than owned"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	var restored := _new_game()
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "crafted and equipped mantle survives save/load"):
		return
	if not _verify(restored.player.get_armor() == 6, "equipped mantle armor restores"):
		return
	print("WOLF PELT CRAFTING OK: drop, recipe, inventory safety, equipment and save/load")
	quit(0)
