extends SceneTree

## Summoner (spirit wolves, crystal totem) and Guardian (oath: half damage,
## reflection, healing).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SUMMONER TEST FAILED: " + reason)
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
	hero.level = 8
	hero.max_mana = 200
	hero.mana = 200
	hero.global_position = Vector2(1500, 900)
	hero.facing = Vector2.RIGHT

	# Spirit wolf: runs to the foe and bites with the spell's element.
	game.selected_spell_id = "frostbolt"
	var foe := _foe(game, hero.global_position + Vector2(80, 0))
	if not game.skills.use("spirit_wolf"):
		return _fail("summon a spirit")
	var spirit: SpiritAlly = null
	for node in game.get_children():
		if node is SpiritAlly:
			spirit = node
	if spirit == null or spirit.element != "ice":
		return _fail("an ice spirit")
	var hp := foe.health
	for i in 90:
		await physics_frame
	if foe.health >= hp or foe.slow_time_left <= 0.0:
		return _fail("the spirit bites and chills")
	game.skills.cooldowns.clear()
	game.skills.use("spirit_wolf")
	game.skills.cooldowns.clear()
	game.skills.use("spirit_wolf")
	await process_frame
	var count := game.get_children().filter(func(n: Node) -> bool: return n is SpiritAlly and not n.is_queued_for_deletion()).size()
	if count != 2:
		return _fail("two spirits at most (%d)" % count)
	spirit = game.get_children().filter(func(n: Node) -> bool: return n is SpiritAlly and not n.is_queued_for_deletion())[0]
	spirit.life = 0.01
	for i in 3:
		await physics_frame
	if is_instance_valid(spirit) and not spirit.is_queued_for_deletion():
		return _fail("spirits fade")

	# Crystal totem: zaps as the chosen spell (reactions work).
	game.selected_spell_id = "chain_lightning"
	foe.slow_time_left = 0.0
	foe.slow_factor = 1.0
	foe.shock_time_left = 0.0
	hero.level = 8
	if not game.skills.use("crystal_totem"):
		return _fail("totem placed")
	var totem: CrystalTotem = null
	for node in game.get_children():
		if node is CrystalTotem:
			totem = node
	if totem == null or totem.element != "lightning":
		return _fail("lightning totem")
	hp = foe.health
	for i in 70:
		await physics_frame
	if foe.health >= hp:
		return _fail("the totem zaps")

	# Guardian's oath.
	if not game.skills.use("guardian_oath") or hero.oath_left <= 0.0:
		return _fail("oath taken")
	hero.max_health = 1000
	hero.health = 1000
	var attacker := _foe(game, hero.global_position + Vector2(-20, 0))
	hp = attacker.health
	hero.take_damage(100, attacker)
	var lost := 1000 - hero.health
	if attacker.health >= hp:
		return _fail("the blow is reflected")
	await process_frame
	if lost <= 0 or lost > 60 or hero.health <= 1000 - lost:
		return _fail("half damage and healing (%d)" % lost)
	print("SUMMONER OK: spirit wolves, totem, guardian oath")
	quit(0)
