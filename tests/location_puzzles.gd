extends SceneTree

## Этап 24: secrets of the lands — the rune stones of the pass (each touch
## flips neighbours) and the bells of the spires (an order from a riddle).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("PUZZLES FAILED: " + reason)
	quit(1)

func _pieces(game: SkywardGame, id: String) -> Array:
	var result: Array = []
	for node in game.get_tree().get_nodes_in_group("puzzle_piece"):
		if node.has_meta("puzzle") and str(node.get_meta("puzzle")) == id and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var puzzles := game.puzzles
	# The pass: five stones, two asleep at the start.
	game._set_region("stone_pass", Vector2(700, 640), false)
	for i in 14:
		await physics_frame
	var stones := _pieces(game, "pass_runes")
	if stones.size() != 5:
		return _fail("five rune stones in the pass")
	var map := game.world.get_world_2d().navigation_map
	for stone in stones:
		var near := NavigationServer2D.map_get_closest_point(map, stone.global_position)
		if near.distance_to(stone.global_position) > 24.0:
			return _fail("a stone stands where one can walk: %s" % str(stone.global_position))
	var lit: Array = puzzles._state("pass_runes")["lit"]
	if not lit.has(false) or not lit.has(true):
		return _fail("scrambled at the start: %s" % str(lit))
	# A wrong touch does not solve it; touching back and the right ones does.
	puzzles.touch("pass_runes", 4)
	puzzles.touch("pass_runes", 4)
	var gold := hero.gold
	puzzles.touch("pass_runes", 0)
	if not puzzles.touch("pass_runes", 2) or not puzzles.solved("pass_runes") or hero.gold < gold + 220:
		return _fail("waking all five solves it and pays")
	for i in 2:
		await process_frame
	if not _pieces(game, "pass_runes").is_empty():
		return _fail("a solved puzzle leaves only its plate")
	# The spires: four bells, the order of the sun.
	game._set_region("wind_spires", Vector2(300, 500), false)
	for i in 14:
		await physics_frame
	var bells := _pieces(game, "spire_bells")
	if bells.size() != 4:
		return _fail("four bells in the spires")
	map = game.world.get_world_2d().navigation_map
	for bell in bells:
		var near := NavigationServer2D.map_get_closest_point(map, bell.global_position)
		if near.distance_to(bell.global_position) > 24.0:
			return _fail("a bell stands where one can walk: %s" % str(bell.global_position))
	puzzles.touch("spire_bells", 1)
	puzzles.touch("spire_bells", 0)
	if int(puzzles._state("spire_bells")["step"]) != 0:
		return _fail("a wrong bell silences them all")
	# Saved mid-way.
	puzzles.touch("spire_bells", 1)
	puzzles.touch("spire_bells", 2)
	var snapshot := game.make_save_snapshot()
	puzzles.state.clear()
	if not game.restore_save_snapshot(snapshot) or int(game.puzzles._state("spire_bells")["step"]) != 2:
		return _fail("progress survives a save")
	puzzles = game.puzzles
	hero = game.player
	var tomes := int(hero.inventory.get("tome_of_forgetting", 0))
	puzzles.touch("spire_bells", 3)
	if not puzzles.touch("spire_bells", 0) or int(hero.inventory.get("tome_of_forgetting", 0)) != tomes + 1:
		return _fail("east, south, west, north: solved, a Book of Forgetting")
	if not game.director.has_flag("puzzle_spire_bells") or int(game.achievements.stats.get("puzzles", 0)) != 2:
		return _fail("remembered and counted")
	print("PUZZLES OK")
	quit()
