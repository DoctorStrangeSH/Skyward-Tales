extends SceneTree

## Этап 24: special halls of the Pattern Vault — an ambush hall (foes rush
## in, a gold chest after), a spring of the Pattern, a hall with a loot imp.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("VAULT HALLS FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	var ex := game.expeditions
	var seen := {}
	for run in 6:
		ex.start()
		for i in 3:
			await process_frame
		for kind in ex.hall_kinds.values():
			seen[kind] = true
		if ex.hall_kinds.values().count("ambush") != 1 or ex.hall_kinds.has(Expeditions.PUZZLE_HALL):
			return _fail("one ambush hall a run, never the puzzle hall")
		for cell in ex.hall_kinds:
			if cell in [Expeditions.START_HALL, Expeditions.BOSS_HALL, Expeditions.TREASURE_HALL]:
				return _fail("special halls are fight halls")
		ex.leave()
		game._travel("greenreach", Vector2(900, 600))
		for i in 3:
			await process_frame
	if not (seen.has("shrine") and seen.has("imp")):
		return _fail("springs and imps show up across runs: %s" % str(seen))
	# The ambush.
	ex.start()
	for i in 3:
		await process_frame
	var cell := ex._ambush_cell()
	var rect := Expeditions.hall_rect(cell)
	for enemy in game._living_enemies():
		if rect.grow(10).has_point(enemy.global_position):
			return _fail("the ambush hall is quiet at first")
	hero.global_position = rect.get_center()
	ex._update_ambush(hero.global_position)
	if ex._ambush_state != "fighting" or ex._ambush_foes.size() != 7:
		return _fail("stepping in springs the ambush: %d" % ex._ambush_foes.size())
	for foe in ex._ambush_foes:
		(foe as SlimeEnemy).take_damage(99999999)
	for i in 3:
		await process_frame
	ex._update_ambush(hero.global_position)
	var chests := game.get_children().filter(func(n: Node) -> bool: return n is TreasureChest and rect.has_point(n.global_position))
	if ex._ambush_state != "done" or chests.is_empty():
		return _fail("the ambush beaten — a chest in the hall")
	# The spring: once a run.
	hero.health = 100
	if not ex.drink() or hero.health <= 100 or ex.drink():
		return _fail("the spring heals once a run")
	print("VAULT HALLS OK")
	quit()
