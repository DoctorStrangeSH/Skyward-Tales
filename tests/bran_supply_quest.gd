extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("BRAN SUPPLY QUEST FAILED: " + reason)
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
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game.quests.complete_quest("moonleaf_gathering")
	game._on_merchant_interacted(null)
	if not _verify(game.hud.dialogue_label.text.contains("Торговец Бран"), "merchant dialogue opens"):
		return
	if not _verify(game.hud.dialogue_choices_container.get_child_count() >= 2, "merchant offers the supply quest"):
		return
	game._on_dialogue_choice_selected("merchant_quest_start")
	if not _verify(game.quests.active_quest_id == "bran_supply_run", "supply quest starts"):
		return
	var crates: Array[Node] = []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id.begins_with("supply_crate_"):
			crates.append(node)
	if not _verify(crates.size() == 3, "three physical supply crates spawn"):
		return
	var first_crate: Node = crates[0]
	game._on_herb_interacted(first_crate)
	if not _verify(int(game.quests.states["bran_supply_run"].get("progress", 0)) == 1, "first crate increments quest progress"):
		return
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	game._set_region("greenreach", Vector2(130, 210), false)
	var remaining_after_travel := 0
	for node in game.get_children():
		if node is WorldCollectible and node.item_id.begins_with("supply_crate_"):
			remaining_after_travel += 1
	if not _verify(remaining_after_travel == 2, "collected crate does not respawn after changing regions"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	var restored := _new_game()
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "active supply quest snapshot restores"):
		return
	if not _verify(restored.quests.active_quest_id == "bran_supply_run", "active quest survives restore"):
		return
	if not _verify(int(restored.quests.states["bran_supply_run"].get("progress", 0)) == 1, "collected crate progress survives save/load"):
		return
	var restored_crates := 0
	for node in restored.get_children():
		if node is WorldCollectible and node.item_id.begins_with("supply_crate_"):
			restored_crates += 1
	if not _verify(restored_crates == 2, "remaining crates survive save/load without restoring collected crates"):
		return
	var collectables: Array[Node] = []
	for node in restored.get_children():
		if node is WorldCollectible and node.item_id.begins_with("supply_crate_"):
			collectables.append(node)
	for crate in collectables:
		restored._on_herb_interacted(crate)
	if not _verify(restored.quests.is_ready_to_complete("bran_supply_run"), "collecting all crates completes objective"):
		return
	var gold_before: int = restored.player.gold
	var xp_before: int = restored.player.experience
	restored._on_merchant_interacted(null)
	if not _verify(restored.hud.dialogue_label.text.contains("вернул все три ящика"), "merchant offers consequence choice after delivery"):
		return
	restored._on_dialogue_choice_selected("merchant_supply:clinic")
	if not _verify(restored.quests.is_completed("bran_supply_run"), "clinic branch completes the quest"):
		return
	if not _verify(restored.quests.states["bran_supply_run"].get("choice", "") == "clinic", "selected branch is saved"):
		return
	if not _verify(restored.player.gold == gold_before + 15 and restored.player.experience > xp_before, "clinic branch grants its data-driven reward"):
		return
	if not _verify(restored.relationships.get_score("bran") == 20 and restored.relationships.get_score("elder") == 10, "clinic branch improves merchant and village relationships"):
		return
	var completed_snapshot: Dictionary = restored.make_save_snapshot()
	if not _verify(completed_snapshot["quest"]["states"]["bran_supply_run"].get("choice", "") == "clinic", "choice is included in save snapshot"):
		return
	var fair_game := _new_game()
	await process_frame
	fair_game.quests.start_quest("bran_supply_run")
	fair_game.quests.add_progress("bran_supply_run", 3)
	fair_game._on_dialogue_choice_selected("merchant_supply:fair")
	if not _verify(fair_game.quests.is_completed("bran_supply_run") and fair_game.player.gold == 40, "fair sale branch grants forty gold"):
		return
	if not _verify(fair_game.relationships.get_score("bran") == 8 and fair_game.relationships.get_score("elder") == 0, "fair sale branch has distinct relationship consequences"):
		return
	print("BRAN SUPPLY QUEST OK: availability, crates, persistence, rewards and consequences")
	quit(0)
