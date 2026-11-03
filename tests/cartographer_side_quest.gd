extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("CARTOGRAPHER SIDE QUEST FAILED: " + detail)
		quit(1)
		return false
	return true

func _find_cartographer(game: Node) -> WorldNpc:
	for node in game.get_children():
		if node is WorldNpc and node.display_name == "Мира, картограф":
			return node
	return null

func _find_fragments(game: Node) -> Array[WorldCollectible]:
	var result: Array[WorldCollectible] = []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "map_fragment":
			result.append(node)
	return result

func _close_dialogue(game: Node) -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var cartographer := _find_cartographer(game)
	if not _verify(cartographer != null, "cartographer NPC spawned in Greenreach"):
		return
	if not _verify(_find_fragments(game).size() == 2, "two journal pages spawned"):
		return
	cartographer.interact()
	if not _verify(not game.quests.states["lost_cartographer_notes"]["started"], "quest locked before helping elder"):
		return
	_close_dialogue(game)
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game.quests.complete_quest("moonleaf_gathering")
	cartographer.interact()
	if not _verify(game.quests.active_quest_id == "lost_cartographer_notes", "cartographer quest starts after main quest"):
		return
	if not _verify(game.hud.dialogue_label.text.contains("два обрывка"), "quest introduction dialogue"):
		return
	_close_dialogue(game)
	var fragments := _find_fragments(game)
	fragments[0].interact()
	await process_frame
	if not _verify(int(game.quests.states["lost_cartographer_notes"]["progress"]) == 1, "first page progress"):
		return
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	game._set_region("greenreach", Vector2(130, 210), false)
	if not _verify(_find_fragments(game).size() == 1, "only missing page respawns after region travel"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not _verify(game.restore_save_snapshot(snapshot), "partial quest save restore"):
		return
	if not _verify(_find_fragments(game).size() == 1, "partial quest collectibles restored"):
		return
	_find_fragments(game)[0].interact()
	await process_frame
	if not _verify(game.quests.is_ready_to_complete("lost_cartographer_notes"), "both pages collected"):
		return
	var old_gold: int = game.player.gold
	var old_xp: int = game.player.experience
	var old_mana_potions: int = int(game.player.inventory.get("mana_potion", 0))
	cartographer = _find_cartographer(game)
	cartographer.interact()
	if not _verify(game.hud.dialogue_visible and game.hud.dialogue_choices_container.get_child_count() == 2, "two reward choices are shown"):
		return
	if not _verify(not game.quests.is_completed("lost_cartographer_notes"), "quest waits for player choice"):
		return
	game._on_dialogue_choice_selected("supplies")
	if not _verify(game.quests.is_completed("lost_cartographer_notes"), "quest completed after choice"):
		return
	if not _verify(str(game.quests.states["lost_cartographer_notes"].get("choice", "")) == "supplies", "selected choice stored in quest state"):
		return
	if not _verify(game.player.gold == old_gold + 10 and game.player.experience == old_xp + 25, "supplies choice grants configured gold and XP"):
		return
	if not _verify(int(game.player.inventory.get("mana_potion", 0)) == old_mana_potions + 2, "supplies choice grants two mana potions"):
		return
	var chosen_snapshot: Dictionary = game.make_save_snapshot()
	if not _verify(game.restore_save_snapshot(chosen_snapshot), "selected quest choice save restore"):
		return
	if not _verify(str(game.quests.states["lost_cartographer_notes"].get("choice", "")) == "supplies", "selected choice survives save/load"):
		return
	_close_dialogue(game)
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	game._set_region("greenreach", Vector2(130, 210), false)
	if not _verify(_find_fragments(game).is_empty(), "completed quest pages do not respawn"):
		return
	cartographer = _find_cartographer(game)
	cartographer.interact()
	if not _verify(game.hud.dialogue_label.text.contains("припасы"), "follow-up dialogue reflects the saved choice"):
		return
	print("CARTOGRAPHER SIDE QUEST OK: unlock, collect, travel, save/restore, choice and consequence")
	quit(0)
