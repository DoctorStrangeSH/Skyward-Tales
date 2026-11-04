extends SceneTree

## Act II finale, the Shattered Isle: the bridge opens after the Tempest,
## four shades (kill quest, blinking casters), the throne wakes Vail (blinks,
## rings of orbs, shades at half health), his fall ends Act II. Saves keep it.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("STORY RIFT TEST FAILED: " + reason)
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
	set_meta("skyward_new_hero", {"name": "Арина", "gender": "f"})
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	await _finish_scenes()

	# Fast-forward to the end of the Wind Spires.
	game.quests.start_quest("main_echo")
	game.director._complete("main_echo")
	await _finish_scenes()
	for quest_id in ["main_bridge", "main_archive", "main_spires"]:
		game.director._complete(quest_id)
		await _finish_scenes()
	game._set_region("wind_spires", Vector2(1100, 300), false)
	await _finish_scenes()
	game._on_region_travel("sky_rift", Vector2(150, 430))
	await _settle()
	if not _verify(game.current_region == "wind_spires", "the rift bridge is closed before the Tempest falls"):
		return
	game.director._complete("main_tempest")
	await _finish_scenes()
	if not _verify(game.quests.active_quest_id == "main_rift", "the Shattered Isle chapter starts"):
		return

	game._on_region_travel("sky_rift", Vector2(150, 430))
	await _settle()
	if not _verify(game.current_region == "sky_rift" and game.story.scene_id == "rift_arrival", "arrival on the Shattered Isle"):
		return
	await _finish_scenes()
	if not _verify(_count("shade") == 4, "four shades haunt the isle"):
		return
	if not _verify(_all("rift_throne").is_empty(), "the throne waits for its chapter"):
		return

	# Shades blink next to the hero.
	var shade: RiftShade = null
	for node in game.get_children():
		if node is RiftShade:
			shade = node
	game.player.global_position = shade.global_position + Vector2(60, 0)
	if not _verify(shade.blink() and shade.global_position.distance_to(game.player.global_position) < 130.0, "a shade blinks next to the hero"):
		return

	# Kill quest: four shades finish the chapter by themselves.
	var shades := []
	for node in game.get_children():
		if node is RiftShade:
			shades.append(node)
	for target in shades:
		target.take_damage(9999)
		await _settle()
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_rift") and game.quests.active_quest_id == "main_vail", "four shades complete the chapter"):
		return

	var throne := _all("rift_throne")
	if not _verify(throne.size() == 1, "the throne appears"):
		return
	game._on_herb_interacted(throne[0])
	if not _verify(game.story.scene_id == "vail_confront", "Vail speaks at the throne"):
		return
	game.story.skip()
	await process_frame
	var vail: VailBoss = null
	for node in game.get_children():
		if node is VailBoss:
			vail = node
	if not _verify(vail != null and vail.max_health == 420 and SkywardGame.enemy_kind(vail) == "vail", "Vail joins the fight"):
		return
	if not _verify(GameAudio.instance().current_track == "boss", "boss music for Vail"):
		return
	var before := vail.global_position
	game.player.global_position = vail.global_position + Vector2(0, 80)
	if not _verify(vail.blink() and vail.global_position != before, "Vail blinks"):
		return

	var snapshot := game.make_save_snapshot()
	vail.take_damage(vail.max_health / 2 + 5)
	await process_frame
	if not _verify(_count("shade") == 2, "at half health Vail calls two shades"):
		return
	var orbs_before := 0
	for node in game.get_children():
		if node is EnemyMagicOrb:
			orbs_before += 1
	vail.ring()
	var orbs_after := 0
	for node in game.get_children():
		if node is EnemyMagicOrb:
			orbs_after += 1
	if not _verify(orbs_after - orbs_before == 8, "a ring of eight orbs"):
		return
	vail.take_damage(9999)
	await _settle()
	if not _verify(game.story.scene_id == "vail_falls", "Vail's fall plays"):
		return
	await _finish_scenes()
	if not _verify(game.quests.is_completed("main_vail") and game.director.has_flag("vail_defeated"), "Act II is complete"):
		return
	game.spawn_enemy("vail", Vector2(900, 320))
	if not _verify(_count("vail") == 0, "Vail never returns"):
		return

	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	var restored_vail := false
	for node in restored.get_children():
		if node is VailBoss:
			restored_vail = true
	if not _verify(restored_vail and restored.current_region == "sky_rift", "mid-fight save keeps Vail"):
		return
	print("STORY RIFT OK: bridge gate, shades blink, kill quest, throne, Vail blinks/summons/rings, Act II ends, save/load")
	quit(0)
