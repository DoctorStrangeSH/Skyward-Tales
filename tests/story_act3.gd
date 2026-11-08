extends SceneTree

## Act III "The Last Pillar": Elian's truth, three Keeper echoes across the
## world, the bridge to the Heart of the Sky, the Voice of the Pattern and
## the final choice with its ending.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STORY ACT III TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _settle() -> void:
	for _i in range(3):
		game.pending_level_choices.clear()
		game.hud.hide_talent_choices()
		paused = false
		await process_frame

func _finish_scenes(close_dialogues: bool = true) -> void:
	for _i in range(14):
		await _settle()
		if game.story.active:
			game.story.skip()
		elif game.hud.dialogue_visible and close_dialogues:
			game.hud.close_dialogue()
			game.player.set_physics_process(true)
		elif not game.director.has_pending():
			return

func _object(item_id: String) -> WorldCollectible:
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == item_id and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	set_meta("skyward_new_hero", {"name": "Арина", "gender": "f"})
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.director.auto_chapters = true
	game.classic_balance = true
	await process_frame
	game.autosave_enabled = false
	game.player.max_health = 99999
	game.player.health = 99999
	await _finish_scenes()
	# Fast-forward through Acts I and II.
	game.quests.start_quest("main_echo")
	game.director._complete("main_echo")
	await _finish_scenes()
	for quest_id in ["main_bridge", "main_archive", "main_spires", "main_tempest", "main_rift", "main_vail"]:
		game.director._complete(quest_id)
		await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_elder", "Act III opens with Elian's chapter"):
		return
	game._set_region("greenreach", Vector2(560, 520), false)
	await _settle()
	if not _verify(game.director.try_talk("elder"), "talking to Elian plays his truth"):
		return
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_echoes", "the echoes chapter follows"):
		return
	game._set_region("sky_rift", Vector2(900, 300), false)
	await _settle()
	game._on_region_travel("sky_heart", Vector2(640, 740))
	await _settle()
	if not _verify(game.current_region == "sky_rift", "the bridge to the Heart stays shut before the echoes"):
		return
	for pair in [["misty_marsh", "keeper_echo_marsh"], ["salt_coast", "keeper_echo_coast"], ["stone_pass", "keeper_echo_pass"]]:
		game._set_region(pair[0], Vector2(400, 400), false)
		game.spawn_story_objects()
		await _settle()
		var echo := _object(pair[1])
		if not _verify(echo != null, "the echo waits in " + pair[0]):
			return
		game.pickups.handle(echo)
		await _finish_scenes()
	if not _verify(game.quests.is_completed("main_echoes") and game.quests.active_quest_id == "main_ascent", "three echoes open the ascent"):
		return
	game._set_region("sky_rift", Vector2(900, 300), false)
	await _settle()
	game._on_region_travel("sky_heart", Vector2(640, 740))
	await _finish_scenes()
	if not _verify(game.current_region == "sky_heart" and game.quests.is_completed("main_ascent"), "arriving at the Heart completes the ascent"):
		return
	if not _verify(game.quests.active_quest_id == "main_heart", "the final chapter begins"):
		return
	game.spawn_story_objects()
	await _settle()
	var core := _object("pattern_core")
	if not _verify(core != null, "the core of the Pattern is in the Heart"):
		return
	game.pickups.handle(core)
	await _finish_scenes()
	var voice: SlimeEnemy = null
	for node in game.get_children():
		if node is PatternVoice:
			voice = node
	if not _verify(voice != null and voice.max_health >= 1000, "the Voice of the Pattern rises"):
		return
	voice.take_damage(999999)
	await _finish_scenes(false)
	if not _verify(game.quests.is_completed("main_heart"), "the Voice's fall completes the chapter"):
		return
	if not _verify(game.hud.dialogue_visible, "the final choice is offered"):
		return
	game.hud.close_dialogue()
	await _settle()
	await _settle()
	if not _verify(game.hud.dialogue_visible, "closing the choice brings it back"):
		return
	game._on_dialogue_choice_selected("finale:lower")
	await _settle()
	if not _verify(game.director.has_flag("ending_lower"), "the choice is remembered"):
		return
	await _finish_scenes()
	if not _verify(game.story.scene_id == "ending_lower" or game.director.has_flag("ending_lower"), "the ending plays"):
		return
	var data := game.make_save_snapshot()
	game.director.flags.clear()
	game.restore_save_snapshot(data)
	if not _verify(game.director.has_flag("ending_lower"), "the ending is saved"):
		return
	print("STORY ACT III OK: Elian, echoes, locked bridge, Heart, Voice, choice, ending, save")
	quit(0)
