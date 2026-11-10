extends SceneTree

## Stage 21, step 6: the Flooded Cistern — channels under water, drain
## plates, crabs from the silt, the Keeper, a refill with the new season.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CISTERN FAILED: " + reason)
	quit(1)

func _pools(game: SkywardGame) -> Array:
	var result: Array = []
	for node in game.get_children():
		if node is Cistern.Pool and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _chests(game: SkywardGame) -> int:
	var count := 0
	for node in game.get_children():
		if node is TreasureChest and not node.is_queued_for_deletion() and node.chest_id.begins_with("cistern_"):
			count += 1
	return count

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var cistern := game.cistern

	# The way down is by the village well.
	var way := false
	for node in game.get_children():
		if node is RegionGate and node.target_region == Cistern.REGION:
			way = true
	if not way:
		return _fail("a grate by the well leads down")
	game._travel(Cistern.REGION, Vector2(216, 700))
	await process_frame
	await process_frame
	var pools := _pools(game)
	if pools.size() != 3:
		return _fail("three channels: %d" % pools.size())
	for pool in pools:
		if not pool.flooded or (pool._body.get_child(0) as CollisionShape2D).disabled:
			return _fail("channels are flooded and block the way")
	if cistern._boss == null or not cistern._boss.has_meta("cistern_keeper"):
		return _fail("the Keeper waits")

	# Plates work in order.
	cistern.press(1)
	if cistern.level != 0:
		return _fail("the second plate does nothing yet")
	var crabs_before := 0
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("cistern_crab"):
			crabs_before += 1
	cistern.press(0)
	await process_frame
	await process_frame
	if cistern.level != 1 or pools[0].flooded or not (pools[0]._body.get_child(0) as CollisionShape2D).disabled:
		return _fail("the first channel runs dry")
	var crabs := 0
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("cistern_crab"):
			crabs += 1
			if not Cistern.POOLS[0].has_point(node.global_position):
				return _fail("crabs crawl out of the channel")
	if crabs - crabs_before != 2:
		return _fail("two crabs from the silt")
	cistern.press(0)
	if cistern.level != 1:
		return _fail("a plate works once")
	cistern.press(1)
	cistern.press(2)
	await process_frame
	if cistern.level != 3 or _chests(game) != 2:
		return _fail("all dry; chests on the bottom: %d" % _chests(game))

	# The Keeper.
	var keeper := cistern._boss
	game._strike(keeper, 999999, Vector2.RIGHT, 0.0)
	for i in 4:
		await process_frame
	if not cistern.cleared or cistern.times_cleared != 1 or _chests(game) != 3:
		return _fail("the Keeper falls, the gold chest appears")
	if game.achievements.progress("cistern_keeper") != 1:
		return _fail("an achievement for the Keeper")

	# Same season: stays dry. Save and load.
	var snapshot := cistern.make_snapshot()
	cistern.restore_snapshot({})
	cistern.restore_snapshot(snapshot)
	game._travel("greenreach", Vector2(668, 752))
	await process_frame
	game._travel(Cistern.REGION, Vector2(216, 700))
	await process_frame
	await process_frame
	if not cistern.cleared or cistern._boss != null or _pools(game)[0].flooded:
		return _fail("the cistern stays dry within the season")

	# A new season floods it again.
	game._travel("greenreach", Vector2(668, 752))
	await process_frame
	game.day_night.day = Seasons.LENGTH
	game._travel(Cistern.REGION, Vector2(216, 700))
	await process_frame
	await process_frame
	if cistern.cleared or cistern.level != 0 or cistern._boss == null or not _pools(game)[2].flooded or cistern.runs != 1:
		return _fail("the rains fill the cistern with the new season")
	if _chests(game) != 0:
		return _fail("old chests are gone")
	print("CISTERN OK")
	quit(0)
