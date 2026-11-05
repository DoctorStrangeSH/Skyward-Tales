extends SceneTree

## Elemental combos (Этап 12): steam blinds, overload blasts, crystal chain,
## shatter and conduct on sword hits, the imbued blade, the codex and
## achievements, and resetting skills for a new build.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("COMBOS TEST FAILED: " + reason)
	quit(1)

func _slime(game: SkywardGame, at: Vector2) -> SlimeEnemy:
	var enemy := game.spawn_enemy("slime", at)
	enemy.max_health = 5000
	enemy.health = 5000
	enemy.set_physics_process(false)
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
	var base := Vector2(1500, 900)
	var a := _slime(game, base)
	var b := _slime(game, base + Vector2(30, 0))
	var c := _slime(game, base + Vector2(0, 30))

	# Steam: ice on burning blinds everyone around.
	a.apply_burning(3, 2.0)
	a.react_to_spell("frostbolt")
	if a.burn_time_left > 0.0 or b.blind_time_left <= 0.0 or a.blind_time_left <= 0.0 or b.slow_time_left <= 0.0:
		return _fail("steam blinds and slows the crowd")
	if not game.combos.seen.has("steam") or game.achievements.progress("combo_first") != 1:
		return _fail("steam is discovered")

	# Overload: fire on shocked blasts the neighbours.
	for e in [a, b, c]:
		e.slow_time_left = 0.0
		e.slow_factor = 1.0
		e.blind_time_left = 0.0
	a.react_to_spell("chain_lightning")
	if a.shock_time_left <= 0.0:
		return _fail("lightning shocks")
	var hp_b := b.health
	a.react_to_spell("fireball")
	if a.shock_time_left > 0.0 or b.health >= hp_b or not game.combos.seen.has("overload"):
		return _fail("overload blasts neighbours")

	# Crystal chain: lightning on a chilled foe hits every chilled foe near.
	a.apply_slow(0.4, 2.0)
	b.apply_slow(0.4, 2.0)
	hp_b = b.health
	a.react_to_spell("chain_lightning")
	if b.health >= hp_b or not game.combos.seen.has("crystal"):
		return _fail("crystal chain")

	# Sword on a chilled foe: shatter (+60%).
	b.slow_time_left = 0.0
	b.slow_factor = 1.0
	c.apply_slow(0.4, 2.0)
	var hp_c := c.health
	game._strike(c, 10, Vector2.RIGHT, 0.0)
	var dealt := hp_c - c.health
	if dealt < 16 or not game.combos.seen.has("shatter"):
		return _fail("shatter deals more (%d)" % dealt)

	# Sword on a shocked foe: the blow conducts.
	c.apply_shock(2.0)
	var hp_a := a.health
	game._strike(c, 10, Vector2.RIGHT, 0.0)
	if a.health >= hp_a or not game.combos.seen.has("conduct"):
		return _fail("conduct arcs to neighbours")

	# The imbued blade.
	game.player.level = 6
	game.player.mana = game.player.max_mana
	game.selected_spell_id = "frostbolt"
	var mana := game.player.mana
	if not game.skills.use("imbue") or game.player.mana != mana - 15 or not game.combos.imbued():
		return _fail("imbue costs mana and enchants the blade")
	for e in [a, b, c]:
		e.slow_time_left = 0.0
		e.slow_factor = 1.0
		e.shock_time_left = 0.0
	game._strike(b, 5, Vector2.RIGHT, 0.0)
	if b.slow_time_left <= 0.0:
		return _fail("an ice blade chills")
	if game.skills.cooldown_left("imbue") <= 0.0:
		return _fail("imbue has a cooldown")

	# A new build: skills reset for gold.
	game.player.level = 8
	var health := game.player.max_health
	SkillTree.learn(game.player, "vitality")
	SkillTree.learn(game.player, "fire_power")
	if game.player.max_health != health + 15 or SkillTree.available_points(game.player) != 5:
		return _fail("skills learned")
	game.player.gold = 500
	if not game.reset_skills():
		return _fail("reset works")
	if game.player.max_health != health or SkillTree.available_points(game.player) != 7 or game.player.gold != 500 - 240:
		return _fail("points, health and gold after the reset")

	# Codex.
	var codex := game.combos.codex()
	if codex.size() != 6 or codex.filter(func(e: Dictionary) -> bool: return e["seen"]).size() != 5:
		return _fail("codex lists six combos, five found")
	game.hud.toggle_skill_tree(game.player)
	game.hud.skills_view.show_group("combos")
	if game.hud.skills_view.columns.get_child_count() != 1:
		return _fail("combos tab")
	var snap := game.combos.make_snapshot()
	game.combos.seen.clear()
	game.combos.restore_snapshot(snap)
	if game.combos.seen.size() != 5:
		return _fail("found combos are saved")
	print("COMBOS OK: steam, overload, crystal chain, shatter, conduct, imbue, reset, codex")
	quit(0)
