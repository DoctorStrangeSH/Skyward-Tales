extends SceneTree

## Act II, Wind Spires: the bridge opens after the archive, three wind runes,
## Mira closes the chapter, the storm heart wakes the Tempest Colossus (gusts,
## wisps on enrage), its defeat restores the second pillar. Boss state saves.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STORY SPIRES TEST FAILED: " + reason)
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

func _count(script_class: String) -> int:
	var total := 0
	for node in game.get_children():
		if node is SlimeEnemy and not node.is_queued_for_deletion() and SkywardGame.enemy_kind(node) == script_class:
			total += 1
	return total

func _run() -> void:
	set_meta("skyward_new_hero", {"name": "Арен", "gender": "m"})
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	await _finish_scenes()

	# Fast-forward: Act I done, Mira joined, archive chapter in progress.
	game.quests.start_quest("main_echo")
	game.director._complete("main_echo")
	await _finish_scenes()
	game._set_region("sky_island", Vector2(1100, 470), false)
	game.director.on_region_entered("sky_island")
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_archive", "the archive chapter is active on the island"):
		return
	game._on_region_travel("wind_spires", Vector2(150, 470))
	await _settle()
	if not _verify(game.current_region == "sky_island", "the spires bridge is closed before the archive"):
		return
	game.director._complete("main_archive")
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_spires", "the spires chapter starts after the archive"):
		return

	game._on_region_travel("wind_spires", Vector2(150, 470))
	await _settle()
	if not _verify(game.current_region == "wind_spires" and game.story.scene_id == "spires_arrival", "arrival at the Wind Spires"):
		return
	await _finish_scenes()
	if not _verify(_count("wisp") == 4 and _count("sentinel") == 1, "wisps and a sentinel guard the spires"):
		return
	if not _verify(_all("storm_heart").is_empty(), "the storm heart waits for its chapter"):
		return

	# Mira closes the chapter only after the runes.
	game._try_interact()
	await _finish_scenes()
	if not _verify(not game.quests.is_completed("main_spires"), "Mira waits for the runes"):
		return
	var runes := _all("wind_rune")
	if not _verify(runes.size() == 3, "three wind runes"):
		return
	for rune in runes:
		game._on_herb_interacted(rune)
		await _finish_scenes()
	game.update_npc_markers()
	if not _verify(game.dialogues.marker_for("cartographer") == "ready", "Mira is marked once the runes are calm"):
		return
	game.player.global_position = Vector2(900, 700)
	game.companion.global_position = Vector2(880, 700)
	game._try_interact()
	if not _verify(game.story.scene_id == "mira_runes", "talking to Mira plays the runes scene"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_spires") and game.quests.active_quest_id == "main_tempest", "the storm heart chapter begins"):
		return

	# The storm heart wakes the boss.
	var heart := _all("storm_heart")
	if not _verify(heart.size() == 1, "the storm heart appears"):
		return
	game._on_herb_interacted(heart[0])
	if not _verify(game.story.scene_id == "tempest_vail", "Vail waits at the storm heart"):
		return
	game.story.skip()
	await process_frame
	var boss: TempestColossus = null
	for node in game.get_children():
		if node is TempestColossus:
			boss = node
	if not _verify(boss != null and boss.max_health == 300 and SkywardGame.enemy_kind(boss) == "tempest", "the Tempest Colossus rises"):
		return

	# Gust pushes the hero back.
	game.player.global_position = boss.global_position + Vector2(0, 60)
	var before := game.player.global_position.distance_to(boss.global_position)
	boss.gust()
	if not _verify(game.player.global_position.distance_to(boss.global_position) > before + 20.0, "the gust pushes the hero away"):
		return

	var snapshot := game.make_save_snapshot()
	boss.take_damage(boss.max_health / 2 + 5)
	await process_frame
	if not _verify(_count("wisp") >= 6, "the enraged colossus calls two wisps"):
		return
	boss.take_damage(9999)
	await _settle()
	if not _verify(game.story.scene_id == "spire_restored", "the pillar scene plays"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_tempest") and game.director.has_flag("tempest_defeated"), "the second pillar is restored"):
		return
	game.spawn_enemy("tempest", Vector2(760, 300))
	if not _verify(_count("tempest") == 0, "the colossus never returns"):
		return

	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	var restored_boss := false
	for node in restored.get_children():
		if node is TempestColossus:
			restored_boss = true
	if not _verify(restored_boss and restored.current_region == "wind_spires", "mid-fight save keeps the colossus"):
		return
	print("STORY SPIRES OK: bridge gate, runes, Mira, storm heart, colossus gusts and wisps, pillar restored, save/load")
	quit(0)
