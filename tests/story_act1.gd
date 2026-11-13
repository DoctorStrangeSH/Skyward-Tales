extends SceneTree

## Act I main line in story mode: Mira's star map, Vail in the grove,
## the freed guardian and its key, Dorn and the altar, the Echo Warden boss
## (bats on enrage) and the act finale. Story flags survive save/load.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STORY ACT I TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _settle() -> void:
	# Close talent pop-ups from level ups and let queued scenes start.
	for _i in range(3):
		game.pending_level_choices.clear()
		game.hud.hide_talent_choices()
		paused = false
		await process_frame

func _finish_scenes() -> void:
	for _i in range(10):
		await _settle()
		if game.story.active:
			game.story.skip()
		elif game.hud.dialogue_visible:
			game.hud.close_dialogue()
			game.player.set_physics_process(true)
		elif not game.director.has_pending():
			return

func _find(item_id: String) -> WorldCollectible:
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == item_id and not node.is_queued_for_deletion():
			return node
	return null

func _boss(kind: Script) -> SlimeEnemy:
	for node in game.get_children():
		if node.get_script() == kind and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	set_meta("skyward_new_hero", {"name": "Арен", "gender": "m"})
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.director.auto_chapters = true
	game.classic_balance = true
	await process_frame
	game.autosave_enabled = false
	await _finish_scenes()
	game._on_herb_interacted(_find("sky_shard"))
	await _finish_scenes()
	game._on_elder_interacted(null)
	await _finish_scenes()
	game.quests.add_progress("moonleaf_gathering", 3)
	game._on_dialogue_choice_selected("village")
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_star_map", "chapter 1 starts after the moonleaf quest"):
		return
	if not _verify(game.dialogues.marker_for("cartographer") == "ready", "Mira is marked as the next step"):
		return
	game._on_cartographer_interacted(null)
	if not _verify(game.story.scene_id == "mira_star_map", "talking to Mira plays the star map scene"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_star_map"), "star map chapter completes"):
		return

	# Chapter 2: the grove.
	game._on_region_travel("moonlit_grove", Vector2(140, 430))
	await _settle()
	if not _verify(game.story.scene_id == "vail_glimpse", "Vail appears on the first visit to the grove"):
		return
	await _finish_scenes()
	game._set_region("greenreach", Vector2(130, 210), false)
	game._on_region_travel("moonlit_grove", Vector2(140, 430))
	await _settle()
	if not _verify(not game.story.active, "Vail's glimpse plays only once"):
		return
	game._on_grove_warden_interacted(null)
	await _finish_scenes()
	game.quests.add_progress("grove_spirits", 3)
	game._on_grove_warden_interacted(null)
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_guardian", "chapter 2 starts after Ilara's quest"):
		return
	var guardian := _boss(load("res://scripts/grove_guardian.gd"))
	if not _verify(guardian != null, "the guardian waits at the stones"):
		return
	guardian.take_damage(9999)
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_guardian") and int(game.player.inventory.get("pattern_key", 0)) == 1, "freed guardian gives the Pattern Key"):
		return

	# Chapter 3: the caves.
	game._on_region_travel("crystal_caves", Vector2(90, 440))
	await _finish_scenes()
	game._on_miner_interacted(null)
	await _finish_scenes()
	game.quests.add_progress("crystal_heart", 4)
	game._on_dialogue_choice_selected("miner_reward:guild")
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_echo", "chapter 3 starts after Dorn's quest"):
		return
	var altar := _find("altar_heart")
	if not _verify(altar != null, "the altar rune appears when the chapter starts"):
		return
	game._on_herb_interacted(altar)
	if not _verify(game.story.scene_id == "altar_vail", "Vail confronts the hero at the altar"):
		return
	game.story.skip()
	await process_frame
	var echo := _boss(load("res://scripts/echo_warden.gd"))
	if not _verify(echo != null and echo.max_health == 220, "the Echo Warden rises"):
		return

	# Save mid-fight: flags and boss survive.
	var snapshot := game.make_save_snapshot()
	if not _verify(bool(snapshot["world"]["story_flags"].get("seen_vail_grove", false)), "story flags are saved"):
		return

	echo.take_damage(echo.max_health / 2 + 5)
	await process_frame
	var bats := 0
	for node in game.get_children():
		if node is CaveBat and not node.is_queued_for_deletion():
			bats += 1
	if not _verify(bats >= 7, "enraged Echo Warden summons two bats"):
		return
	echo.take_damage(9999)
	await _settle()
	if not _verify(game.story.scene_id == "act1_finale", "act finale plays after the boss falls"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_echo") and game.director.has_flag("echo_defeated"), "Act I is complete"):
		return
	game.spawn_enemy("echo", Vector2(1000, 660))
	if not _verify(_boss(load("res://scripts/echo_warden.gd")) == null, "the boss never returns"):
		return

	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot) and restored.director.has_flag("seen_vail_grove"), "flags restore from a save"):
		return
	var restored_echo := false
	for node in restored.get_children():
		if node is EchoWarden:
			restored_echo = true
	if not _verify(restored_echo, "mid-fight save keeps the boss"):
		return
	# Fled and came back: the altar plays the short version of the scene.
	if not _verify(restored.director.has_flag("seen_altar_vail"), "the altar scene is remembered"):
		return
	var again := WorldCollectible.new()
	again.item_id = "altar_heart"
	restored.add_child(again)
	restored._on_herb_interacted(again)
	if not _verify(restored.story.scene_id == "altar_vail_again", "a second try is short: " + restored.story.scene_id):
		return
	restored.story.skip()
	print("STORY ACT I OK: star map, Vail, guardian and key, altar, Echo Warden, finale, save/load")
	quit(0)
