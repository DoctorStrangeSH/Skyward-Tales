extends SceneTree

## Stage 21, step 5: the Tower of Trials — gate, lever, floors, rules,
## blessings, champion, checkpoint, seals, a fall that does not kill.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("TRIAL TOWER FAILED: " + reason)
	quit(1)

func _choices(game: SkywardGame) -> String:
	var text := ""
	for button in game.hud.dialogue_choices_container.get_children():
		text += (button as Button).text + "\n"
	return text

func _labels(game: SkywardGame) -> String:
	var text := ""
	for node in game.get_children():
		if node is TowerObject and not node.is_queued_for_deletion():
			text += node.label + "|"
	return text

func _clear(game: SkywardGame) -> void:
	for foe in game.trials._foes.duplicate():
		game._strike(foe, 999999, Vector2.RIGHT, 0.0)
	for i in 4:
		await process_frame

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var tower := game.trials
	var hero := game.player
	tower.rng.seed = 7

	# The gate stands in Greenreach.
	if not _labels(game).contains("Башня испытаний"):
		return _fail("the gate stands near the village")
	tower.open_gate()
	if not _choices(game).contains("с 1-го этажа") or _choices(game).contains("кристалл"):
		return _fail("the gate offers floor 1 only:\n" + _choices(game))
	game._on_dialogue_choice_selected("trial_enter:1")
	await process_frame
	await process_frame
	if game.current_region != TrialTower.REGION or not tower.active or tower.floor_no != 1:
		return _fail("the hero enters floor 1")
	if not _labels(game).contains("начать испытание"):
		return _fail("the lever waits")

	# Floor 1.
	tower.pull_lever()
	if tower.state != "fight" or tower._foes.size() != 3:
		return _fail("three foes on floor 1: %d" % tower._foes.size())
	for foe in tower._foes:
		if not TrialTower.HALL.has_point(foe.global_position):
			return _fail("foes stand in the hall")
	await _clear(game)
	if tower.state != "cleared" or tower.best != 1 or tower.seals() != 1:
		return _fail("floor 1 cleared, a seal for the record: %s %d" % [tower.state, tower.seals()])
	var labels := _labels(game)
	if not labels.contains("ларец") or not labels.contains("алтарь") or not labels.contains("подняться"):
		return _fail("coffer, altar and stairs appear: " + labels)
	tower.open_coffer()
	if not tower.looted or not _labels(game).contains("алтарь") or _labels(game).contains("ларец"):
		return _fail("the coffer opens once")
	tower.open_altar()
	if tower.offered.size() != 3:
		return _fail("three blessings offered")
	var pick := str(tower.offered[0])
	var type := str(TrialTower.BLESSINGS[pick][2])
	game._on_dialogue_choice_selected("trial_bless:" + pick)
	game._on_dialogue_choice_selected("trial_bless:" + str(tower.offered[1]))
	if tower.blessings.size() != 1 or hero.buff_value(type) <= 0.0:
		return _fail("one blessing per floor")

	# Up: stronger foes, rules from floor 3, a champion on floor 5.
	tower.climb()
	if tower.floor_no != 2 or tower.state != "idle" or hero.global_position.distance_to(TrialTower.START) > 4.0:
		return _fail("the stairs lead to floor 2")
	var mult1 := 0.7
	if tower.health_mult() <= mult1:
		return _fail("floors grow tougher")
	for f in range(2, 5):
		tower.pull_lever()
		await _clear(game)
		if tower.state != "cleared":
			return _fail("floor %d cleared" % f)
		tower.climb()
	if tower.floor_no != 5 or not tower.champion_floor():
		return _fail("floor 5 is the champion's")
	tower.pull_lever()
	var champions := 0
	for foe in tower._foes:
		if foe.combat_feedback.elite_name.contains("Чемпион"):
			champions += 1
	if champions != 1 or tower._foes.size() != 3:
		return _fail("a champion with two guards")
	var seals := tower.seals()
	await _clear(game)
	if tower.checkpoint != 5 or tower.seals() != seals + 3:
		return _fail("the crystal remembers floor 5; 3 seals: %d" % (tower.seals() - seals))
	if game.achievements.progress("tower_climber") != 5:
		return _fail("the climb is an achievement")

	# A fall is not death.
	tower.climb()
	tower.pull_lever()
	hero.take_damage(999999)
	await process_frame
	await process_frame
	if game.game_over or game.current_region != TrialTower.HOME or tower.active or hero.health <= 1:
		return _fail("the tower carries the fallen hero out alive")
	if hero.buff_value(type) > 0.0:
		return _fail("blessings end with the run")
	if tower.best != 5:
		return _fail("the record stays")

	# Checkpoint and prizes.
	tower.open_gate()
	if not _choices(game).contains("с 6-го этажа"):
		return _fail("the gate offers the checkpoint:\n" + _choices(game))
	var potions := int(hero.inventory.get("health_potion", 0))
	game._on_dialogue_choice_selected("trial_shop")
	game._on_dialogue_choice_selected("trial_prize:0")
	if int(hero.inventory.get("health_potion", 0)) != potions + 4 or tower.seals() != seals + 2:
		return _fail("a seal buys potions")
	game._on_dialogue_choice_selected("trial_prize:3")
	if tower.seals() != seals + 2:
		return _fail("not enough seals for a legendary")
	game._on_dialogue_choice_selected("trial_enter:6")
	await process_frame
	await process_frame
	if tower.floor_no != 6:
		return _fail("the run starts above the crystal")
	game._on_dialogue_choice_selected("trial_enter:40")
	await process_frame
	if tower.floor_no != 6:
		return _fail("no skipping past the checkpoint")

	# Save.
	var snapshot := tower.make_snapshot()
	tower.restore_snapshot({})
	tower.restore_snapshot(snapshot)
	if tower.best != 5 or tower.checkpoint != 5:
		return _fail("the tower is saved")
	print("TRIAL TOWER OK")
	quit(0)
