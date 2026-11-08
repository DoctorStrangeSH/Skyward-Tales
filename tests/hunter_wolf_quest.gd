extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("HUNTER WOLF QUEST FAILED: " + reason)
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
	game._on_hunter_interacted(null)
	game.story.skip()
	if not _verify(game.hud.dialogue_speaker_label.text.contains("Торен"), "hunter dialogue opens"):
		return
	game._on_dialogue_choice_selected("hunter_quest_start")
	if not _verify(game.quests.is_active("toren_wolf_hunt"), "wolf hunt starts"):
		return
	game._on_enemy_defeated(5, Vector2.ZERO)
	if not _verify(int(game.quests.states["toren_wolf_hunt"].get("progress", 0)) == 0, "non-wolf kills do not count"):
		return
	game._on_wolf_defeated(8, Vector2.ZERO)
	if not _verify(int(game.quests.states["toren_wolf_hunt"].get("progress", 0)) == 1, "wolf kill increments progress"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	var restored := _new_game()
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "active hunt restores from save"):
		return
	if not _verify(int(restored.quests.states["toren_wolf_hunt"].get("progress", 0)) == 1, "hunt progress survives save/load"):
		return
	restored.quests.add_progress("toren_wolf_hunt", 2)
	restored._on_hunter_interacted(null)
	var gold_before: int = restored.player.gold
	restored._on_dialogue_choice_selected("hunter_reward:supplies")
	if not _verify(restored.quests.is_completed("toren_wolf_hunt"), "supplies choice completes quest"):
		return
	if not _verify(restored.player.gold == gold_before + 20, "supplies choice grants twenty gold"):
		return
	if not _verify(int(restored.player.inventory.get("health_potion", 0)) == 2, "supplies choice grants two health potions"):
		return
	if not _verify(restored.relationships.get_score("toren") == 15, "supplies choice improves hunter trust"):
		return
	var fair := _new_game()
	await process_frame
	fair.quests.start_quest("toren_wolf_hunt")
	fair.quests.add_progress("toren_wolf_hunt", 3)
	fair._on_dialogue_choice_selected("hunter_reward:gold")
	if not _verify(fair.player.gold == 35 and fair.relationships.get_score("toren") == 8, "gold choice has distinct reward and trust"):
		return
	print("HUNTER WOLF QUEST OK: gating, wolf-only progress, save/load and reward choices")
	quit(0)
