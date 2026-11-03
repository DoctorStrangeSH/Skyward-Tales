extends SceneTree

## Act II opening in story mode: Mira joins after the Echo Warden, follows the
## hero, fights and heals; the bridge to the sky island opens, the arrival
## completes the bridge chapter, three memory crystals and the archivist's
## truth finish the archive chapter. The companion survives save/load.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STORY ACT II TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _settle() -> void:
	for _i in range(3):
		game.pending_level_choices.clear()
		game.hud.hide_talent_choices()
		paused = false
		await process_frame

func _finish_scenes() -> void:
	for _i in range(12):
		await _settle()
		if game.story.active:
			game.story.skip()
		elif game.hud.dialogue_visible:
			game.hud.close_dialogue()
			game.player.set_physics_process(true)
		elif not game.director.has_pending():
			return

func _all(item_id: String) -> Array:
	var found := []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == item_id and not node.is_queued_for_deletion():
			found.append(node)
	return found

func _run() -> void:
	set_meta("skyward_new_hero", {"name": "Арина", "gender": "f"})
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	await _finish_scenes()

	# The gate to the island stays closed until Act I is over.
	game._set_region("crystal_caves", Vector2(900, 600), false)
	await _finish_scenes()
	game._on_region_travel("sky_island", Vector2(640, 800))
	await _settle()
	if not _verify(game.current_region == "crystal_caves", "the bridge is closed before the Echo Warden falls"):
		return

	# Finish Act I directly: Mira joins.
	game.quests.start_quest("main_echo")
	game.director._complete("main_echo")
	await _finish_scenes()
	if not _verify(game.companion != null and is_instance_valid(game.companion), "Mira joins as a companion"):
		return
	if not _verify(game.quests.active_quest_id == "main_bridge", "the bridge chapter starts"):
		return

	# She follows the hero.
	var start := game.companion.global_position
	game.player.global_position += Vector2(120, 0)
	for _i in range(40):
		await process_frame
	if not _verify(game.companion.global_position.distance_to(game.player.global_position) < start.distance_to(game.player.global_position), "Mira follows the hero"):
		return

	# She fights: a frost vial at a nearby enemy.
	game.spawn_enemy("slime", game.companion.global_position + Vector2(60, 0))
	game.companion.attack_ready_in = 0.0
	await process_frame
	await process_frame
	var bolts := 0
	for node in game.get_children():
		if node is MagicBolt:
			bolts += 1
	if not _verify(bolts >= 1, "Mira throws a frost vial"):
		return

	# She heals when the hero is hurt.
	game.player.health = 10
	game.companion.heal_ready_in = 0.0
	await process_frame
	await process_frame
	if not _verify(game.player.health >= 35, "Mira patches the hero up"):
		return

	# Across the bridge: arrival scene completes the bridge chapter.
	game._on_region_travel("sky_island", Vector2(640, 800))
	await _settle()
	if not _verify(game.current_region == "sky_island", "the bridge leads to the sky island"):
		return
	if not _verify(game.story.scene_id == "island_arrival", "the arrival scene plays"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_bridge") and game.quests.active_quest_id == "main_archive", "arrival opens the archive chapter"):
		return
	if not _verify(game.companion.global_position.distance_to(game.player.global_position) < 60.0, "Mira crosses with the hero"):
		return
	var sentinels := 0
	for node in game.get_children():
		if node is SkySentinel:
			sentinels += 1
			if not _verify(SkywardGame.enemy_kind(node) == "sentinel", "sentinels are their own kind"):
				return
	if not _verify(sentinels == 4, "four sentinels guard the island"):
		return

	# Talking to the archivist early does not finish the chapter.
	game._on_archivist_interacted(null)
	await _finish_scenes()
	if not _verify(not game.quests.is_completed("main_archive"), "the archivist waits for the crystals"):
		return
	var crystals := _all("memory_crystal")
	if not _verify(crystals.size() == 3, "three memory crystals on the island"):
		return
	for crystal in crystals:
		game._on_herb_interacted(crystal)
		await _finish_scenes()
	if not _verify(game.quests.is_ready_to_complete("main_archive"), "crystals advance the archive chapter"):
		return

	# Save with the companion, restore into a fresh game.
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	if not _verify(restored.companion != null and is_instance_valid(restored.companion), "Mira is still with the hero after loading"):
		return
	restored.queue_free()

	game._on_archivist_interacted(null)
	if not _verify(game.story.scene_id == "archive_truth", "the archivist reveals the truth"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_archive"), "archive chapter completes"):
		return
	print("STORY ACT II OK: Mira joins/follows/fights/heals, bridge, island, sentinels, crystals, archivist, save/load")
	quit(0)
