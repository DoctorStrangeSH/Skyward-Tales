extends SceneTree

## Этап 24: the escort errand — Vedana walks to the sanctuary, waits for a
## hero who falls behind, ambushes go for her, she can fall (another try),
## arriving pays and is remembered.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("ESCORT FAILED: " + reason)
	quit(1)

func _clear(game: SkywardGame) -> void:
	for node in game.get_children():
		if node is SlimeEnemy and not node.has_meta("escort"):
			node.free()

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var escort := game.escort
	if escort.available():
		return _fail("not before the marsh")
	while hero.level < EscortErrand.LEVEL:
		hero.add_experience(hero.experience_to_next)
	game.quests.states["marsh_lanterns"] = {"started": true, "completed": true, "progress": 1}
	game._set_region(EscortErrand.REGION, Vector2(420, 280), false)
	for i in 14:
		await physics_frame
	_clear(game)
	if not escort.available() or escort.marker(EscortErrand.NPC) != "quest":
		return _fail("Vedana asks for an escort")
	escort.start()
	if not escort.active or escort.walker == null or escort._route.size() < 2:
		return _fail("she sets off along a path")
	# The hero stays behind: she waits.
	hero.global_position = escort.walker.global_position + Vector2(0, -400)
	escort._process(0.1)
	var at := escort.walker.global_position
	for i in 30:
		await physics_frame
	if escort.walker.global_position.distance_to(at) > 1.0:
		return _fail("she waits for a hero who fell behind")
	# Walk beside her until the first ambush.
	var guard := 0
	while escort._next_ambush == 0 and guard < 4000:
		hero.global_position = escort.walker.global_position + Vector2(20, 0)
		escort._process(0.016)
		escort.walker._process(0.25)
		guard += 1
	if escort._foes.size() != 3:
		return _fail("the first ambush: three foes, got %d" % escort._foes.size())
	for foe in escort._foes:
		if (foe as SlimeEnemy).taunt != escort.walker:
			return _fail("the ambush goes for her")
	at = escort.walker.global_position
	escort.walker._process(1.0)
	if escort.walker.global_position.distance_to(at) > 1.0:
		return _fail("she stops while attacked")
	# She falls: the errand waits.
	escort.walker.take_damage(9999)
	escort._process(0.1)
	if escort.active or not game.quests.is_active(EscortErrand.QUEST):
		return _fail("a fallen Vedana calls it off, the errand waits")
	for i in 3:
		await process_frame
	# Again, all the way.
	escort.start()
	guard = 0
	while escort.active and guard < 8000:
		hero.global_position = escort.walker.global_position + Vector2(20, 0)
		for foe in escort._foes:
			if is_instance_valid(foe):
				(foe as SlimeEnemy).take_damage(99999)
		escort._process(0.016)
		if escort.walker != null:
			escort.walker._process(0.25)
		guard += 1
		if guard % 50 == 0:
			await process_frame
	if escort.active or not game.quests.is_completed(EscortErrand.QUEST) or not game.director.has_flag("vedana_escorted"):
		return _fail("she reaches the sanctuary: done and remembered (guard %d)" % guard)
	if escort._next_ambush != 2:
		return _fail("two ambushes on the way")
	print("ESCORT OK")
	quit()
