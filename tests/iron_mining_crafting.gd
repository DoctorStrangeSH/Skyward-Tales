extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("IRON MINING AND CRAFTING FAILED: " + reason)
		quit(1)
		return false
	return true

func _new_game() -> Node2D:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	return game

func _count_ore_nodes(game: Node2D) -> int:
	var count := 0
	for actor in game.get_children():
		if actor is WorldCollectible and actor.item_id.begins_with("iron_ore_node_"):
			count += 1
	return count

func _run() -> void:
	var game := _new_game()
	await process_frame
	if not _verify(_count_ore_nodes(game) == 3, "three iron deposits spawn in Greenreach"):
		return
	var deposits: Array[WorldCollectible] = []
	for actor in game.get_children():
		if actor is WorldCollectible and actor.item_id.begins_with("iron_ore_node_"):
			deposits.append(actor)
	for deposit in deposits:
		game._on_herb_interacted(deposit)
	await process_frame
	if not _verify(int(game.player.inventory.get("iron_ore", 0)) == 3, "each deposit grants one iron ore"):
		return
	if not _verify(_count_ore_nodes(game) == 0, "collected deposits disappear"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	var restored := _new_game()
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "mining progress saves and loads"):
		return
	if not _verify(int(restored.player.inventory.get("iron_ore", 0)) == 3, "ore inventory survives save/load"):
		return
	if not _verify(_count_ore_nodes(restored) == 0, "collected deposits do not respawn after loading"):
		return
	restored.player.add_item("apprentice_staff")
	restored.player.add_gold(49)
	var insufficient: Dictionary = restored.crafting_service.get_recipe_status(restored.player, "forge_ironbound_staff")
	if not _verify(not bool(insufficient.get("success", false)), "crafting is blocked when gold is one short"):
		return
	if not _verify(int(restored.player.inventory.get("iron_ore", 0)) == 3, "failed craft consumes no ore"):
		return
	restored.player.add_gold(1)
	restored._on_blacksmith_interacted(null)
	if not _verify(restored.hud.dialogue_choices_container.get_child_count() >= 2, "Borin offers iron staff recipe when requirements are met"):
		return
	restored._on_dialogue_choice_selected("blacksmith_craft:ironbound_staff")
	if not _verify(int(restored.player.inventory.get("iron_ore", 0)) == 0, "three ore are consumed exactly"):
		return
	if not _verify(int(restored.player.inventory.get("ironbound_staff", 0)) == 1, "ironbound staff is crafted"):
		return
	if not _verify(restored.player.gold == 0, "fifty gold are consumed exactly"):
		return
	if not _verify(restored.player.equip_item("ironbound_staff"), "ironbound staff can be equipped"):
		return
	if not _verify(restored.player.get_spell_bonus("fireball") == 8, "ironbound staff grants eight universal spell damage"):
		return
	var final_snapshot: Dictionary = restored.make_save_snapshot()
	var final_restore := _new_game()
	await process_frame
	if not _verify(final_restore.restore_save_snapshot(final_snapshot), "crafted staff survives save/load"):
		return
	if not _verify(final_restore.player.get_spell_bonus("fireball") == 8, "equipped staff bonus restores"):
		return
	print("IRON MINING AND CRAFTING OK: deposits, persistence, costs, recipe, equipment and save/load")
	quit(0)
