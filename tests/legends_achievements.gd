extends SceneTree

## Legendary beasts appear only at night, slip away at dawn, drop a unique
## trophy once; achievements count progress, pay gold and are saved.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("LEGENDS TEST FAILED: " + reason)
	quit(1)

func _legend(game: SkywardGame) -> SlimeEnemy:
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("legend") and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	game.day_night.time = 0.5
	game._set_region("moonlit_grove", Vector2(400, 400), false)
	await process_frame
	await process_frame
	if _legend(game) == null:
		return _fail("the grove is always dark: its legend is out")
	game._set_region("salt_coast", Vector2(400, 600), false)
	await process_frame
	await process_frame
	if _legend(game) != null:
		return _fail("no legend by day")
	game.day_night.time = 0.92
	await process_frame
	await process_frame
	var crab := _legend(game)
	if crab == null or crab.get_meta("legend") != "stone_crab" or crab.max_health < 150:
		return _fail("the Granite Crab roams the coast at night")
	game.day_night.time = 0.5
	await process_frame
	await process_frame
	if _legend(game) != null:
		return _fail("the legend slips away at dawn")
	game.day_night.time = 0.92
	await process_frame
	await process_frame
	crab = _legend(game)
	var gold := game.player.gold
	crab.take_damage(999999)
	await process_frame
	var trophy := false
	for node in game.get_children():
		if node is WorldLoot and node.item_id == "crab_aegis":
			trophy = true
	if not trophy or not game.legends.defeated.has("stone_crab"):
		return _fail("the trophy drops")
	await process_frame
	await process_frame
	if _legend(game) != null:
		return _fail("a beaten legend does not come back")
	# Achievements: first kill and first legend.
	if not game.achievements.done.has("first_blood") or not game.achievements.done.has("legend_1"):
		return _fail("first blood and night hunt unlock")
	if game.player.gold < gold + 160:
		return _fail("achievements pay gold")
	game._handle_key(KEY_J)
	game.hud.journal_view.show_tab("ach")
	if game.hud.journal_view.detail_box.get_child_count() == 0:
		return _fail("the journal lists achievements")
	var data := GameSaveState.capture(game)
	game.achievements.done.clear()
	game.legends.defeated.clear()
	GameSaveState.apply(game, data)
	if not game.achievements.done.has("legend_1") or not game.legends.defeated.has("stone_crab"):
		return _fail("legends and achievements are saved")
	print("LEGENDS OK: night only, dawn retreat, trophy, once, achievements, journal, save")
	quit(0)
