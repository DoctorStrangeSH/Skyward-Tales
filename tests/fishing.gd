extends SceneTree

## Fishing minigame: early strike scares the fish, a missed bite escapes,
## hooking and reeling catches a fish into the log; spot rests; journal tabs.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("FISHING TEST FAILED: " + reason)
	quit(1)

func _spot(game: SkywardGame) -> GatherNode:
	for node in game.get_children():
		if node is GatherNode and node.kind == "fish":
			return node
	return null

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	var spot := _spot(game)
	if spot == null:
		return _fail("greenreach has a fishing spot")
	hero.global_position = spot.global_position + Vector2(0, 20)
	var fishing := game.fishing
	fishing.manual_input = true

	# Striking too early scares the fish.
	if not game.crafting.gather(spot) or fishing.state != "waiting" or not game.hud.fishing_view.visible:
		return _fail("E at a spot casts the line and shows the panel")
	if hero.is_physics_processing():
		return _fail("the hero stands still while fishing")
	fishing.press()
	if fishing.active() or not spot.available or not hero.is_physics_processing():
		return _fail("an early strike ends fishing without resting the spot")

	# Missing the bite lets the fish go.
	game.crafting.gather(spot)
	fishing.timer = 0.0
	await _frames(2)
	if fishing.state != "bite":
		return _fail("the float dives after the wait")
	fishing.timer = 0.0
	await _frames(2)
	if fishing.active():
		return _fail("a missed bite escapes")

	# Hook and reel: keep the zone on the fish until the bar fills.
	fishing.rng.seed = 5
	game.crafting.gather(spot)
	fishing.species = "perch"
	fishing.difficulty = 0.42
	fishing.timer = 0.0
	await _frames(2)
	fishing.press()
	if fishing.state != "reel":
		return _fail("hooking starts the reel")
	var result := {"caught": ""}
	fishing.finished.connect(func(id: String) -> void: result["caught"] = id)
	for i in 900:
		if not fishing.active():
			break
		fishing.holding = fishing.fish_pos > fishing.zone + fishing.zone_width * 0.5
		await process_frame
	if result["caught"] != "perch" or int(hero.inventory.get("perch", 0)) != 1:
		return _fail("following the fish catches it (got '%s')" % result["caught"])
	if int(hero.fish_log.get("perch", {}).get("count", 0)) != 1 or int(hero.fish_log["perch"]["best"]) < 20:
		return _fail("the catch goes into the log with its size")
	if spot.available or game.crafting.gather(spot):
		return _fail("the spot rests after a catch")

	# Letting go loses the fish.
	var other: GatherNode = null
	for node in game.get_children():
		if node is GatherNode and node.kind == "fish" and node != spot:
			other = node
	if other != null:
		result["caught"] = ""
		game.crafting.gather(other)
		fishing.timer = 0.0
		await _frames(2)
		fishing.press()
		fishing.holding = false
		fishing.zone = 0.0
		fishing.fish_target = 0.95
		fishing.fish_pos = 0.95
		fishing.fish_timer = 99.0
		for i in 400:
			if not fishing.active():
				break
			await process_frame
		if fishing.active() or result["caught"] != "":
			return _fail("a fish outside the zone gets away")

	# Save keeps the log; journal shows tabs and the fishing page.
	var data := GameSaveState.capture(game)
	hero.fish_log = {}
	GameSaveState.apply(game, data)
	if not game.player.fish_log.has("perch"):
		return _fail("the fishing log is saved")
	game._handle_key(KEY_J)
	var journal := game.hud.journal_view
	if not game.hud.journal_visible or journal.entry_list.get_child_count() == 0:
		return _fail("the journal shows a list and details")
	journal.show_tab("fish")
	if journal.detail_box.get_child_count() < 9:
		return _fail("the fishing tab lists every species")
	if game.hud.quest_tracker.visible == game.hud.quest_tracker.entries.is_empty():
		return _fail("the tracker shows the active quest")
	print("FISHING OK: cast, early strike, missed bite, reel, catch, log, rest, escape, save, journal, tracker")
	quit(0)
