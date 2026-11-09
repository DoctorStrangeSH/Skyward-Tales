extends SceneTree

## Stage 20: three spells that are not bolts — «Огненная волна» (a fan of
## fire), «Ледяная стена» (ice blocks that stop foes) and «Шаровая молния»
## (a slow orb that zaps foes around). Form spells wait for the level.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SPELL FORMS FAILED: " + reason)
	quit(1)

func _clear(game: SkywardGame) -> void:
	for node in game.get_tree().get_nodes_in_group("enemies"):
		node.queue_free()

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.director.set_flag("magic_unlocked")
	_clear(game)
	await process_frame
	var hero := game.player
	hero.level = 20
	hero.max_mana = 999
	hero.mana = 999
	var here := hero.global_position

	for id in ["fire_wave", "ice_wall", "ball_lightning"]:
		if not game.spell_definitions.has(id) or not CombatSkills.is_spell(id) or not ResourceLoader.exists("res://assets/icons/skill_%s.png" % id):
			return _fail("%s is a spell with an icon" % id)
		if Trainers.teacher_of(id).is_empty() or Trainers.price_of(id) <= 0:
			return _fail("%s is taught by a trainer" % id)
		if not ElementalCombos.ELEMENT_OF.has(id) or not PlayerCharacter.ELEMENT_STATS.has(id):
			return _fail("%s has an element" % id)

	# The level gate.
	hero.level = 6
	if game.skills.lock_reason("fire_wave") != "Ур. 7" or not game.skills.lock_reason("fireball").is_empty():
		return _fail("form spells wait for the level: " + game.skills.lock_reason("fire_wave"))
	hero.level = 20

	# Огненная волна: foes in the fan burn, the one behind doesn't.
	var front := game.spawn_enemy("wolf", here + Vector2(60, 0))
	var side := game.spawn_enemy("wolf", here + Vector2(50, 40))
	var behind := game.spawn_enemy("wolf", here + Vector2(-60, 0))
	await process_frame
	var hp_front := front.health
	var hp_behind := behind.health
	var struck := SpellForms.fire_wave(game, game.spell_definitions["fire_wave"], Vector2.RIGHT, 20)
	if not struck.has(front) or not struck.has(side) or struck.has(behind):
		return _fail("the wave hits the fan in front: %d struck" % struck.size())
	if front.health >= hp_front or front.burn_time_left <= 0.0 or behind.health != hp_behind:
		return _fail("the wave hurts and burns")
	_clear(game)
	await process_frame

	# Through the casting path: mana, cooldown, the selected spell.
	game.cast_cooldown_remaining = 0.0
	game.select_spell("fire_wave")
	var mana_before := hero.mana
	game._cast_spell()
	if hero.mana != mana_before - 20 or game.cast_cooldown_remaining < 1.0:
		return _fail("casting spends mana and sets the cooldown (%d, %.2f)" % [hero.mana, game.cast_cooldown_remaining])

	# Ледяная стена: five blocks across the aim, solid for foes, then gone.
	var wall := SpellForms.ice_wall(game, game.spell_definitions["ice_wall"], Vector2.RIGHT, 16)
	if wall.get_child_count() != 5 or wall.block_offsets.size() != 5:
		return _fail("the wall has five blocks")
	for body in wall.get_children():
		if not body is StaticBody2D or (body as StaticBody2D).collision_layer != 4:
			return _fail("ice blocks are solid like the world")
	if absf(wall.block_offsets[0].x) > 0.1 or absf(wall.block_offsets[0].y) < 20.0:
		return _fail("the wall stands across the aim")
	var walker := game.spawn_enemy("wolf", wall.global_position + Vector2(40, 0))
	walker.brain_state = SlimeEnemy.BrainState.IDLE
	await process_frame
	await physics_frame
	walker.global_position = wall.global_position + Vector2(12, 0)
	wall._tick = 0.0
	await physics_frame
	await physics_frame
	if walker.slow_time_left <= 0.0:
		return _fail("foes touching the ice slow down")
	var hp_walker := walker.health
	wall.lifetime = 0.01
	await physics_frame
	await physics_frame
	if is_instance_valid(wall) and not wall.is_queued_for_deletion():
		return _fail("the wall melts in time")
	if walker.health >= hp_walker:
		return _fail("the wall shatters with a blow")
	_clear(game)
	await process_frame
	# A foe on a block's spot freezes instead of being walled in.
	var stuck := game.spawn_enemy("wolf", here + Vector2(50, 0))
	await process_frame
	var wall2 := SpellForms.ice_wall(game, game.spell_definitions["ice_wall"], Vector2.RIGHT, 16)
	if wall2.block_offsets.size() != 4 or stuck.slow_factor > 0.2:
		return _fail("a foe on the spot is frozen, not walled in")
	wall2.queue_free()
	_clear(game)
	await process_frame

	# Шаровая молния: zaps the nearest two, not the far one.
	var near_a := game.spawn_enemy("wolf", here + Vector2(30, 10))
	var near_b := game.spawn_enemy("wolf", here + Vector2(30, -20))
	var near_c := game.spawn_enemy("wolf", here + Vector2(36, 30))
	var far := game.spawn_enemy("wolf", here + Vector2(0, 160))
	for foe in [near_a, near_b, near_c, far]:
		foe.brain_state = SlimeEnemy.BrainState.IDLE
	await process_frame
	var orb := SpellForms.ball_lightning(game, game.spell_definitions["ball_lightning"], Vector2.RIGHT, 7)
	orb.velocity = Vector2.ZERO
	var hp_far := far.health
	if orb.zap() != 2:
		return _fail("the orb zaps two foes at a time")
	if far.health != hp_far or near_a.shock_time_left <= 0.0:
		return _fail("only near foes, and they are shocked")
	orb.lifetime = 0.01
	await physics_frame
	await physics_frame
	if is_instance_valid(orb) and not orb.is_queued_for_deletion():
		return _fail("the orb fades")

	print("SPELL FORMS OK")
	quit(0)
