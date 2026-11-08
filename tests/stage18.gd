extends SceneTree

## Этап 18: deep rifts (waves, depth, the Devourer with its shield), expedition
## difficulties (the Keeper of the Abyss), New Game+.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("STAGE 18 TEST FAILED: " + reason)
	quit(1)

func _echoes(game: SkywardGame) -> Array:
	return game.get_children().filter(func(n: Node) -> bool: return n is SlimeEnemy and n.has_meta("rift_echo") and not n.is_queued_for_deletion() and n.health > 0)

func _kill(list: Array) -> void:
	for e in list:
		(e as SlimeEnemy).invulnerable = false
		(e as SlimeEnemy).take_damage(999999)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var deep := game.deep_rifts
	var hero := game.player
	hero.level = 15
	hero.max_health = 99999
	hero.health = 99999

	# --- Deep rifts -----------------------------------------------------------
	if not deep.targets().is_empty():
		return _fail("deep rifts wait for the Shadow")
	game.quests.states["post_shadow"]["completed"] = true
	deep.region = "moonlit_grove"
	game._travel("moonlit_grove", Vector2(640, 500))
	await process_frame
	var rifts := game.get_children().filter(func(n: Node) -> bool: return n is PatternRift)
	if rifts.size() != 1:
		return _fail("the deep rift opens in its land")
	rifts[0].interact()
	await process_frame
	var wave := _echoes(game)
	if wave.size() < 4:
		return _fail("first wave")
	var hp_depth1: int = (wave[0] as SlimeEnemy).max_health
	_kill(wave)
	await process_frame
	await process_frame
	wave = _echoes(game)
	if wave.size() < 5:
		return _fail("second wave (%d)" % wave.size())
	_kill(wave)
	await process_frame
	await process_frame
	if deep.depth != 2 or deep.best != 1 or deep.region == "moonlit_grove":
		return _fail("sealing goes one level deeper elsewhere")
	if deep.targets().size() != 1:
		return _fail("the next deep rift is pinned on the map")

	# A boss depth: the Devourer and its shield.
	deep.depth = 5
	deep.region = "moonlit_grove"
	game._travel("moonlit_grove", Vector2(640, 500))
	await process_frame
	rifts = game.get_children().filter(func(n: Node) -> bool: return n is PatternRift)
	rifts[0].interact()
	await process_frame
	wave = _echoes(game)
	if deep.power() < 1.5 or hp_depth1 <= 0:
		return _fail("deeper echoes are tougher")
	_kill(wave)
	await process_frame
	await process_frame
	var devourer: SlimeEnemy = null
	for e in _echoes(game):
		if e.has_meta("devourer"):
			devourer = e
	if devourer == null:
		return _fail("the Devourer comes out at depth 5")
	devourer.set_physics_process(false)
	var mech: BossMechanics = null
	for c in devourer.get_children():
		if c is BossMechanics:
			mech = c
	devourer.take_damage(roundi(devourer.max_health * 0.4))
	await process_frame
	await process_frame
	if not mech.shielded or not devourer.invulnerable or mech.anchors.size() != 3:
		return _fail("the Devourer raises a shield with three anchors")
	var hp := devourer.health
	devourer.take_damage(5000)
	if devourer.health != hp:
		return _fail("the shield blocks damage")
	for a in mech.anchors:
		(a as SlimeEnemy).set_physics_process(false)
	_kill(mech.anchors.duplicate())
	await process_frame
	await process_frame
	if mech.shielded or devourer.invulnerable:
		return _fail("killing the anchors breaks the shield")
	mech._attack_clock = 0.0
	await process_frame
	if game.get_children().filter(func(n: Node) -> bool: return n is CrystalStrike).size() < 8:
		return _fail("the Devourer's crystal ring")
	_kill([devourer])
	await process_frame
	await process_frame
	await process_frame
	if deep.depth != 6 or not game.achievements.done.has("devourer_slayer") or not game.achievements.done.has("deep_diver"):
		return _fail("the Devourer seals depth 5")
	var snap := deep.make_snapshot()
	deep.restore_snapshot({})
	deep.restore_snapshot(snap)
	if deep.depth != 6 or deep.best != 5:
		return _fail("deep rifts saved")

	# --- Expedition difficulty -----------------------------------------------
	var ex := game.expeditions
	if ex.unlocked_difficulty() != 0:
		return _fail("only normal at first")
	ex.completed = 3
	if ex.unlocked_difficulty() != 1:
		return _fail("heroic after three runs")
	ex.heroic_done = 3
	ex.start(2)
	await process_frame
	if ex.difficulty != 2 or ex.reward_mult() < 3.0:
		return _fail("legendary run")
	hero.global_position = Expeditions.hall_rect(Expeditions.BOSS_HALL).get_center() + Vector2(0, 60)
	await process_frame
	await process_frame
	var abyss: SlimeEnemy = null
	for n in game.get_children():
		if n is SlimeEnemy and n.combat_feedback.elite_name.contains("Бездны"):
			abyss = n
	if abyss == null:
		return _fail("the Keeper of the Abyss waits")
	abyss.set_physics_process(false)
	var count := game.get_children().filter(func(n: Node) -> bool: return n is SlimeEnemy).size()
	abyss.take_damage(abyss.health - abyss.max_health / 2 + 1)
	await process_frame
	await process_frame
	if game.get_children().filter(func(n: Node) -> bool: return n is SlimeEnemy).size() < count + 2:
		return _fail("the Keeper splits into illusions")
	_kill([abyss])
	await process_frame
	if ex.legendary_done != 1 or not game.achievements.done.has("abyss_keeper"):
		return _fail("legendary run counted")
	game._travel("greenreach", Vector2(900, 600))
	await process_frame

	# --- New Game+ --------------------------------------------------------------
	if not TitleMenu.ng_plus_seed({"world": {"story_flags": {}}, "player": {}}).is_empty():
		return _fail("NG+ needs an ending")
	game.director.set_flag("ending_restore")
	hero.add_item("order_blade", 1)
	hero.gold = 4321
	var save := GameSaveState.capture(game)
	var seed := TitleMenu.ng_plus_seed(save)
	if seed.is_empty():
		return _fail("NG+ seed after an ending")
	game.queue_free()
	await process_frame
	var fresh: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	fresh.autosave_enabled = false
	fresh.start_ng_plus(seed)
	await process_frame
	if fresh.ng_plus != 1 or fresh.player.level != int(save["player"]["level"]) or fresh.player.gold < 4321 or not fresh.player.inventory.has("order_blade"):
		return _fail("NG+ keeps the hero (%d %d %d %s)" % [fresh.ng_plus, fresh.player.level, fresh.player.gold, fresh.player.inventory.has("order_blade")])
	if fresh.quests.is_completed("main_echo") or not fresh.quests.is_active("main_prologue"):
		return _fail("NG+ restarts the story")
	if not fresh.achievements.done.has("devourer_slayer") or not fresh.achievements.done.has("second_round"):
		return _fail("NG+ keeps achievements")
	var slime := fresh.spawn_enemy("slime", fresh.player.global_position + Vector2(200, 0))
	var plain := (load("res://scripts/enemy.gd") as GDScript).new() as SlimeEnemy
	if slime.max_health <= plain.max_health * 1.4:
		return _fail("NG+ foes are tougher (%d vs %d)" % [slime.max_health, plain.max_health])
	plain.free()
	if int(GameSaveState.capture(fresh)["world"]["ng_plus"]) != 1:
		return _fail("NG+ round saved")
	print("STAGE 18 TEST PASSED")
	quit(0)
