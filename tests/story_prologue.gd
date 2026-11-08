extends SceneTree

## Character creation → prologue scene → sky shard → Elian → moonleaf quest.
## Gendered text, the main story section of the journal and save/load.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STORY PROLOGUE TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	# Character creation in the title menu.
	var menu: Control = load("res://scenes/title_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._start_new()
	if not _verify(menu.creation.visible and not menu.menu_column.visible, "new game opens character creation"):
		return
	menu.creation.select_gender("f")
	if not _verify(menu.creation.name_edit.text == "Арина", "default name follows the chosen look"):
		return
	menu.creation.name_edit.text = "Лира"
	var hero: Dictionary = menu.creation.hero_data()
	if not _verify(hero == {"name": "Лира", "gender": "f"}, "creation returns name and look"):
		return
	root.remove_child(menu)
	menu.queue_free()

	# Starting the adventure plays the prologue.
	set_meta("skyward_new_hero", hero)
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	if not _verify(game.player.hero_name == "Лира" and game.player.hero_gender == "f", "identity applied to the hero"):
		return
	if not _verify(game.story.active and game.story.scene_id == "prologue", "prologue scene is playing"):
		return
	if not _verify(game.quests.active_quest_id == "main_prologue", "prologue quest is active"):
		return
	var saw_female_form := false
	while game.story.active:
		if game.hud.dialogue_label.text.contains("цела") or game.hud.dialogue_label.text.contains("Лира"):
			saw_female_form = true
		game.story.advance()
	if not _verify(saw_female_form, "lines use the hero's name and gender"):
		return
	if not _verify(not game.hud.dialogue_visible and game.player.is_physics_processing(), "scene ends and control returns"):
		return

	# Elian points to the shard until it is inspected.
	game._on_elder_interacted(null)
	if not _verify(game.hud.dialogue_label.text.contains("северных руин"), "Elian sends the hero to the ruins"):
		return
	game.hud.close_dialogue()
	var shard: WorldCollectible = null
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "sky_shard":
			shard = node
	if not _verify(shard != null, "sky shard waits at the ruins"):
		return
	game._on_herb_interacted(shard)
	if not _verify(game.story.active and game.story.scene_id == "shard_inspect", "inspecting the shard plays its scene"):
		return
	game.story.skip()
	if not _verify(game.quests.is_completed("main_prologue"), "prologue quest completes"):
		return
	await process_frame
	var shard_left := false
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "sky_shard" and not node.is_queued_for_deletion():
			shard_left = true
	if not _verify(not shard_left, "shard disappears after inspection"):
		return

	# Elian reacts, then gives the moonleaf quest.
	game._on_elder_interacted(null)
	if not _verify(game.story.active and game.story.scene_id == "elder_after_shard", "Elian reacts to the glowing seal"):
		return
	game.story.skip()
	if not _verify(bool(game.quests.states["moonleaf_gathering"]["started"]) and game.hud.dialogue_visible, "moonleaf quest starts after the scene"):
		return
	var entries := QuestJournalPanel.build_entries(game.quests)
	if not _verify(entries["active"][0]["main"] and entries["completed"][0]["id"] == "main_prologue", "journal tracks the main story"):
		return
	game._on_dialogue_choice_selected("payment") # not ready yet: ignored
	game.quests.add_progress("moonleaf_gathering", 3)
	game.hud.close_dialogue()
	game._on_elder_interacted(null)
	game.story.skip()
	if not _verify(game.hud.dialogue_label.text.contains("спасла"), "gendered verb in Elian's reward line"):
		return

	# Identity survives save/load.
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot) and restored.player.hero_name == "Лира" and StoryText.hero_gender == "f", "identity survives save/load"):
		return
	print("STORY PROLOGUE OK: creation, prologue, shard, Elian, journal, gendered text, save/load")
	quit(0)
