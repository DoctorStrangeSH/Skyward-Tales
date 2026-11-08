extends SceneTree

## Этап 15: expeditions into the Pattern Vault (modifiers, rune seal, warden,
## rewards, save) and the multi-stage legend hunt with Toren.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("STAGE 15 TEST FAILED: " + reason)
	quit(1)

func _plates(game: SkywardGame) -> Array:
	return game.get_children().filter(func(n: Node) -> bool: return n is RunePlate)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var ex := game.expeditions

	# The vault is hidden from the world map.
	if "pattern_vault" in RegionCatalog.ids() or not "pattern_vault" in RegionCatalog.all_ids():
		return _fail("the vault is a hidden land")

	# Ragna offers an expedition.
	game.guild.talk()
	if not game.guild.handle_choice("guild_expedition"):
		return _fail("guild expedition choice")
	await process_frame
	if game.current_region != Expeditions.REGION or not ex.active:
		return _fail("the expedition starts in the vault")
	if ex.modifier != "calm":
		return _fail("the first run is calm")
	var foes := game.get_children().filter(func(n: Node) -> bool: return n is SlimeEnemy and n.has_meta("vault"))
	if foes.size() < 10:
		return _fail("the halls are guarded (%d)" % foes.size())
	for foe in foes:
		foe.set_physics_process(false)
	var plates := _plates(game)
	if plates.size() != 4:
		return _fail("four rune plates")
	var seal: DungeonDoor = null
	for node in game.get_children():
		if node is DungeonDoor and node.door_id == Expeditions.SEAL:
			seal = node
	if seal == null or seal.is_open:
		return _fail("the treasure hall is sealed")
	if ex.targets().size() != 2:
		return _fail("map pins for the seal and the warden")

	# A wrong rune wakes guards and resets.
	var wrong_index := int(ex.order[1])
	var before := game.get_children().filter(func(n: Node) -> bool: return n is SlimeEnemy).size()
	ex._on_plate(plates.filter(func(p: RunePlate) -> bool: return p.rune == wrong_index)[0])
	await process_frame
	var after := game.get_children().filter(func(n: Node) -> bool: return n is SlimeEnemy).size()
	if after != before + 2 or ex.progress != 0:
		return _fail("a wrong rune summons two guards (%d → %d)" % [before, after])
	# The right order opens the seal.
	for index in ex.order:
		ex._on_plate(plates.filter(func(p: RunePlate) -> bool: return p.rune == int(index))[0])
	if not ex.solved or not seal.is_open or not bool(game.opened_doors.get(Expeditions.SEAL, false)):
		return _fail("the right order opens the seal")
	if game.achievements.stats.get("rune_puzzles", 0) != 1:
		return _fail("rune puzzle achievement stat")
	# Stepping onto a plate by walking.
	for plate in plates:
		plate.lit = false
	ex.solved = false
	ex.progress = 0
	var first: RunePlate = plates.filter(func(p: RunePlate) -> bool: return p.rune == int(ex.order[0]))[0]
	hero.global_position = first.global_position + Vector2(40, 0)
	await process_frame
	hero.global_position = first.global_position
	await process_frame
	await process_frame
	if ex.progress != 1:
		return _fail("walking onto a rune presses it")
	ex.solved = true

	# The warden wakes in the far hall.
	hero.global_position = Expeditions.hall_rect(Expeditions.BOSS_HALL).get_center() + Vector2(0, 60)
	await process_frame
	await process_frame
	if not ex.warden_spawned:
		return _fail("the warden wakes when the hero enters its hall")
	var warden: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("vault") and node.combat_feedback.elite_name.contains("Страж"):
			warden = node
	if warden == null or warden.max_health < 100:
		return _fail("a tough warden")
	var loot_before := game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot).size()
	ex._on_warden_down(warden.global_position)
	if ex.completed != 1 or not ex.warden_down:
		return _fail("expedition completed")
	if game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot).size() < loot_before + 2:
		return _fail("the warden pays out")
	if not game.achievements.done.has("vault_runner"):
		return _fail("expedition achievement")

	# Save keeps the count; leaving ends the run.
	var snap: Dictionary = ex.make_snapshot()
	game._travel("greenreach", Vector2(480, 600))
	await process_frame
	await process_frame
	if ex.active:
		return _fail("leaving the vault ends the run")
	ex.completed = 0
	ex.restore_snapshot(snap)
	if ex.completed != 1:
		return _fail("expedition count saved")

	# A second run rolls a modifier and resets the vault.
	ex.rng.seed = 7
	ex.start()
	await process_frame
	if ex.run != 2 or ex.solved or ex.warden_spawned or not ex.active:
		return _fail("a fresh run")
	if game.opened_doors.has(Expeditions.SEAL):
		return _fail("the seal closes again")
	ex.modifier = "storm"
	ex._storm_clock = 0.0
	await process_frame
	await process_frame
	if game.get_children().filter(func(n: Node) -> bool: return n is CrystalStrike).is_empty():
		return _fail("crystal storm drops crystals")
	game._travel("greenreach", Vector2(480, 600))
	await process_frame

	# --- Legend hunt -------------------------------------------------------
	var legends := game.legends
	game.visited_regions["greenreach"] = true
	var prey := legends.huntable()
	if prey != "slime_king":
		return _fail("the local legend is huntable (%s)" % prey)
	game.quests.states["toren_wolf_hunt"] = {"started": true, "completed": true, "progress": 3}
	game.dialogues.on_hunter()
	if not legends.start_hunt(prey):
		return _fail("start hunt")
	if legends.start_hunt(prey):
		return _fail("one hunt at a time")
	var marks := game.get_children().filter(func(n: Node) -> bool: return n is TrackMark)
	if marks.size() != 3:
		return _fail("three tracks (%d)" % marks.size())
	if legends.hunt_targets().size() != 3:
		return _fail("tracks on the map")
	for mark in marks:
		legends._on_track(mark)
	if str(legends.hunt.get("stage", "")) != "lair":
		return _fail("all tracks lead to the lair")
	if not legends.hunted("slime_king"):
		return _fail("the legend is hunted")
	await process_frame
	var beast: SlimeEnemy = legends._current
	if beast == null or not is_instance_valid(beast):
		return _fail("the hunted legend waits in its lair")
	beast.set_physics_process(false)
	var damage := beast.attack_damage
	beast.health = beast.max_health / 2 - 1
	await process_frame
	await process_frame
	if beast.attack_damage <= damage or not legends._enraged:
		return _fail("phase two: the legend rages")
	# Hunt state survives a save.
	var hunt_snap: Dictionary = legends.make_snapshot()
	if str(hunt_snap.get("hunt", {}).get("stage", "")) != "lair":
		return _fail("hunt saved")
	var loot_count := game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot).size()
	legends._on_defeated("slime_king", beast.global_position)
	if not legends.hunt.is_empty() or legends.hunts_done != 1:
		return _fail("hunt finished")
	if game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot).size() < loot_count + 6:
		return _fail("a hunted legend pays double")
	if not game.achievements.done.has("legend_tracker"):
		return _fail("legend hunt achievement")
	print("STAGE 15 TEST PASSED")
	quit(0)
