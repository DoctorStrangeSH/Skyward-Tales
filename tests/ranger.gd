extends SceneTree

## The ranger: a bow in the weapon slot turns RMB into arrows (hold to aim:
## double damage, pierce), arrows land strikes (imbue and combos work),
## Volley needs a bow, snares root a foe, Toren sells bows.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("RANGER TEST FAILED: " + reason)
	quit(1)

func _foe(game: SkywardGame, at: Vector2) -> SlimeEnemy:
	var enemy := game.spawn_enemy("wolf", at)
	enemy.set_physics_process(false)
	enemy.max_health = 9999
	enemy.health = 9999
	return enemy

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	await process_frame
	var hero := game.player
	hero.level = 6
	hero.global_position = Vector2(1500, 900)
	hero.facing = Vector2.RIGHT

	# Volley is locked without a bow.
	if game.skills.lock_reason("volley") != "Нужен лук":
		return _fail("volley needs a bow")

	# Toren sells bows after his hunt.
	game.quests.states["moonleaf_gathering"]["completed"] = true
	game.quests.states["toren_wolf_hunt"]["started"] = true
	game.quests.states["toren_wolf_hunt"]["completed"] = true
	hero.gold = 500
	game.dialogues.handle_choice("toren_buy:hunting_bow")
	if int(hero.inventory.get("hunting_bow", 0)) != 1 or hero.gold != 380:
		return _fail("Toren sells a hunting bow")
	game.hud.close_dialogue()
	hero.equip_item("hunting_bow")
	if not hero.has_bow() or hero.get_ranged_damage() < 6 + 9 + 6:
		return _fail("the bow is equipped (%d)" % hero.get_ranged_damage())

	# A quick shot.
	var foe := _foe(game, hero.global_position + Vector2(60, 0))
	game._bow_press()
	game._bow_release()
	var arrow: Arrow = null
	for node in game.get_children():
		if node is Arrow:
			arrow = node
	if arrow == null or arrow.aimed:
		return _fail("a quick arrow flies")
	var hp := foe.health
	for i in 30:
		await physics_frame
	if foe.health >= hp:
		return _fail("the arrow hits")
	if game.cast_cooldown_remaining <= 0.0 and game.cast_cooldown_total <= 0.0:
		return _fail("bow cooldown")

	# An aimed shot pierces two foes.
	game.cast_cooldown_remaining = 0.0
	var second := _foe(game, hero.global_position + Vector2(90, 0))
	hp = second.health
	game._bow_press()
	game._bow_held = 1.0
	game._bow_release()
	for i in 30:
		await physics_frame
	if second.health >= hp:
		return _fail("an aimed arrow pierces")

	# Imbued arrows carry the element.
	game.selected_spell_id = "frostbolt"
	hero.mana = hero.max_mana
	game.combos.start_imbue(10.0)
	foe.slow_time_left = 0.0
	foe.slow_factor = 1.0
	game.shoot_arrow(Vector2.RIGHT, 5, false)
	for i in 30:
		await physics_frame
	if foe.slow_time_left <= 0.0:
		return _fail("an ice arrow chills")

	# Volley: five arrows.
	var before := game.get_children().filter(func(n: Node) -> bool: return n is Arrow).size()
	if not game.skills.use("volley"):
		return _fail("volley with a bow")
	if game.get_children().filter(func(n: Node) -> bool: return n is Arrow).size() != before + 5:
		return _fail("five arrows")

	# Snare.
	hero.global_position = Vector2(1200, 900)
	if not game.skills.use("snare"):
		return _fail("snare placed")
	var trap: SnareTrap = null
	for node in game.get_children():
		if node is SnareTrap:
			trap = node
	if trap == null:
		return _fail("trap exists")
	var prey := _foe(game, trap.global_position + Vector2(4, 0))
	hp = prey.health
	for i in 3:
		await physics_frame
	if prey.health >= hp or prey.slow_time_left <= 0.0 or prey.slow_factor > 0.1:
		return _fail("the snare roots its prey")

	# Without a bow RMB casts again.
	hero.unequip_slot("blade")
	if hero.has_bow():
		return _fail("bow removed")
	print("RANGER OK: Toren's bows, shots, aimed pierce, imbued arrows, volley, snare")
	quit(0)
