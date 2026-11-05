extends SceneTree

## Open world layer: region levels and enemy scaling, waystones and fast
## travel, data-driven side-quest giver (Vedana) running alongside the main
## story, per-herb quests, kill quests and a quest-gated side boss.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("OPEN WORLD TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _settle() -> void:
	for _i in range(3):
		game.pending_level_choices.clear()
		game.hud.hide_talent_choices()
		paused = false
		await process_frame

func _of(script_class: String) -> Array:
	var found := []
	for node in game.get_children():
		if not node.is_queued_for_deletion() and node.get_class() != "" and node.get_script() != null and node.get_script().get_global_name() == script_class:
			found.append(node)
	return found

func _herbs(item_id: String) -> Array:
	var found := []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == item_id and not node.is_queued_for_deletion():
			found.append(node)
	return found

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false

	# Levels on every region; the marsh is gated softly by the grove guardian.
	for region_id in RegionCatalog.all():
		if not _verify(RegionCatalog.level(region_id) >= 1, "region has a level: " + str(region_id)):
			return
	if not _verify(RegionCatalog.level("misty_marsh") == 6 and RegionCatalog.level("sky_rift") == 11, "levels rise with the world"):
		return
	game._set_region("moonlit_grove", Vector2(640, 760), false)
	await _settle()
	game._on_region_travel("misty_marsh", Vector2(640, 110))
	await _settle()
	if not _verify(game.current_region == "moonlit_grove", "the marsh trail waits for the grove guardian"):
		return
	game.quests.start_quest("main_guardian")
	game.quests.add_progress("main_guardian", 1)
	game.quests.complete_quest("main_guardian")

	# Waystone in the grove: awaken it, nothing to travel to yet.
	var stones := _of("Waystone")
	if not _verify(stones.size() == 1, "one sky stone per region"):
		return
	if not _verify(game.travel_destinations().is_empty(), "no destinations before awakening"):
		return
	stones[0].interact()
	if not _verify(stones[0].awake and game.waystone_awake("moonlit_grove"), "the stone awakens"):
		return

	game._on_region_travel("misty_marsh", Vector2(640, 110))
	await _settle()
	if not _verify(game.current_region == "misty_marsh", "the marsh opens after the guardian"):
		return
	# Enemies are stronger here (enemy_power 1.6).
	var toads := _of("MarshToad")
	if not _verify(toads.size() == 6 and toads[0].max_health == 48, "marsh toads scaled by the region"):
		return
	if not _verify(_of("BogKing").is_empty(), "the Bog King hides until his quest"):
		return

	# Awaken the marsh stone and fast-travel back and forth.
	_of("Waystone")[0].interact()
	var dest := game.travel_destinations()
	if not _verify(dest.has("moonlit_grove") and dest.has("misty_marsh"), "both stones are destinations"):
		return
	game.open_map()
	if not _verify(game.hud.world_map_view.overview.awake.size() == 2 and game.hud.world_map_view.travel_row.get_child_count() == 3, "the world map knows the awakened stones"):
		return
	if not _verify(game.fast_travel("moonlit_grove") and game.current_region == "moonlit_grove", "fast travel to the grove"):
		return
	await _settle()
	if not _verify(game.fast_travel("misty_marsh") and game.current_region == "misty_marsh", "fast travel back to the marsh"):
		return
	await _settle()

	# A main quest stays tracked while side quests run.
	game.quests.start_quest("crystal_heart")
	var vedana: WorldNpc = null
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "herbalist":
			vedana = node
	if not _verify(vedana != null and game.dialogues.marker_for("herbalist") == "quest", "Vedana offers a quest"):
		return
	vedana.interacted.emit(vedana)
	game._on_dialogue_choice_selected("giver_accept:marsh_lanterns")
	if not _verify(game.quests.is_active("marsh_lanterns") and game.quests.active_quest_id == "crystal_heart", "side quest runs alongside the main one"):
		return
	if not _verify(game.quests.get_side_summaries().size() == 1, "HUD lists the side quest"):
		return
	for herb in _herbs("marsh_lantern"):
		game._on_herb_interacted(herb)
	if not _verify(game.quests.is_ready_to_complete("marsh_lanterns") and game.dialogues.marker_for("herbalist") == "ready", "lanterns gathered"):
		return
	var gold := game.player.gold
	var potions := int(game.player.inventory.get("mana_potion", 0))
	game.givers.talk("herbalist")
	game.hud.close_dialogue()
	if not _verify(game.quests.is_completed("marsh_lanterns") and game.player.gold == gold + 40 and int(game.player.inventory.get("mana_potion", 0)) == potions + 2, "reward with items"):
		return

	# Kill quest: six toads.
	game.givers.talk("herbalist")
	game._on_dialogue_choice_selected("giver_accept:marsh_toads")
	for toad in _of("MarshToad"):
		toad.take_damage(9999)
		await process_frame
	if not _verify(game.quests.is_ready_to_complete("marsh_toads"), "six toads counted"):
		return
	game.givers.talk("herbalist")
	game.hud.close_dialogue()

	# The side boss appears only when his quest opens, and only once.
	game.givers.talk("herbalist")
	game._on_dialogue_choice_selected("giver_accept:marsh_king")
	var kings := _of("BogKing")
	if not _verify(kings.size() == 1 and SkywardGame.enemy_kind(kings[0]) == "bog_king", "the Bog King rises"):
		return
	kings[0].take_damage(kings[0].max_health / 2 + 5)
	await process_frame
	if not _verify(_of("MarshToad").size() == 2, "enraged, he calls two toads"):
		return
	kings[0].take_damage(9999)
	await _settle()
	if not _verify(game.quests.is_ready_to_complete("marsh_king"), "the king counts for the quest"):
		return
	game.givers.talk("herbalist")
	game.hud.close_dialogue()
	if not _verify(game.quests.is_completed("marsh_king") and int(game.player.inventory.get("frost_heart", 0)) >= 1, "the chain pays a rare relic"):
		return
	if not _verify(game.dialogues.marker_for("herbalist") == "", "Vedana has nothing more"):
		return

	# Stones and side progress survive saving.
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	if not _verify(restored.waystone_awake("misty_marsh") and restored.quests.is_completed("marsh_king"), "stones and side quests are saved"):
		return
	if not _verify(restored.quests.active_quest_id == "crystal_heart", "the tracked main quest is saved"):
		return
	print("OPEN WORLD OK: levels, scaling, soft gate, waystones, fast travel, side-quest giver, kill quests, side boss, save/load")
	quit(0)
