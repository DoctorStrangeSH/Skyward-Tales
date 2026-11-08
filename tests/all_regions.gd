extends SceneTree

## Этап 18 smoke test: every land (including hidden ones) builds, the hero
## can stand in it for a moment, nothing errors; prints build times so slow
## regions stand out.

const BUDGET_MS := 4000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.player.max_health = 99999
	game.player.health = 99999
	var worst := 0
	for region_id in RegionCatalog.all_ids():
		var started := Time.get_ticks_msec()
		game._travel(str(region_id), Vector2(400, 400))
		var built := Time.get_ticks_msec() - started
		for i in 5:
			await process_frame
		if game.current_region != str(region_id):
			push_error("ALL REGIONS TEST FAILED: could not enter " + str(region_id))
			quit(1)
			return
		var nodes := game.get_child_count()
		print("region %-14s built in %4d ms, %3d nodes" % [region_id, built, nodes])
		worst = maxi(worst, built)
	if worst > BUDGET_MS:
		push_error("ALL REGIONS TEST FAILED: a region took %d ms" % worst)
		quit(1)
		return
	print("ALL REGIONS TEST PASSED")
	quit(0)
