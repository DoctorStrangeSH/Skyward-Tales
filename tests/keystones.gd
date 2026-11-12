extends SceneTree

## Этап 23: key talents at levels 5/10/15 — offered once in a quiet moment,
## chosen one of three, they change the fight; kept by saves, returned by
## the skill reset.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("KEYSTONES FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var keys := game.keystones
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	if not keys.pending().is_empty():
		return _fail("nothing at level 1")
	while hero.level < 5:
		hero.add_experience(hero.experience_to_next)
	if keys.pending() != [5]:
		return _fail("level 5 opens the first tier")
	# Offered by itself in a quiet moment.
	keys._offer_clock = 0.0
	keys._process(0.1)
	if not game.hud.dialogue_visible or not game.hud.dialogue_speaker_label.text.contains("Путь клинка"):
		return _fail("the choice is offered")
	var labels: Array = game.hud.dialogue_choices_container.get_children().map(func(b: Node) -> String: return (b as Button).text)
	if labels.size() != 4:
		return _fail("three keystones and 'later'")
	game._on_dialogue_choice_selected("keystone:5:berserk")
	if not hero.has_keystone("berserk") or game.hud.dialogue_visible:
		return _fail("berserk is chosen")
	if keys.choose(5, "duelist"):
		return _fail("one per tier")
	# Berserk: low health hits harder.
	var foe := game.spawn_enemy("golem", hero.global_position + Vector2(300, 0))
	foe.set_physics_process(false)
	var full := keys.strike_mult(foe)
	hero.health = 1
	var low := keys.strike_mult(foe)
	hero.health = hero.max_health
	if absf(full - 1.0) > 0.01 or low < 1.45:
		return _fail("berserk %.2f → %.2f" % [full, low])
	# Level 10: headhunter vs an elite; level 15: fortune.
	while hero.level < 15:
		hero.add_experience(hero.experience_to_next)
	keys.choose(10, "headhunter")
	foe.combat_feedback.elite = true
	if keys.strike_mult(foe) < 1.29:
		return _fail("headhunter hits elites harder")
	var gold_before := hero.get_gold_multiplier()
	keys.choose(15, "fortune")
	if hero.get_gold_multiplier() < gold_before * 1.34 or keys.xp_mult() < 1.14:
		return _fail("fortune pays more")
	foe.free()
	# Duelist after a reset: the blow after a roll is a sure crit.
	hero.gold = 5000
	if game.reset_skills():
		return _fail("no reset without a Book of Forgetting")
	hero.add_item(SkillTree.RESET_TOME, 1)
	if not game.reset_skills() or not hero.keystones.is_empty() or SkillTree.tomes(hero) != 0:
		return _fail("the reset returns key talents")
	keys.choose(5, "duelist")
	keys.on_dodge()
	if not keys.take_sure_crit() or keys.take_sure_crit():
		return _fail("one sure crit after a roll")
	# Saves keep them.
	var snapshot := game.make_save_snapshot()
	hero.keystones.clear()
	if not game.restore_save_snapshot(snapshot) or not game.player.has_keystone("duelist"):
		return _fail("key talents survive a save")
	# Two defeats by the same boss: the defeat screen gives a hint.
	hero = game.player
	var boss := game.spawn_enemy("guardian", hero.global_position + Vector2(200, 0))
	boss.set_physics_process(false)
	hero.last_attacker = boss
	if not game.defeat_tip().is_empty():
		return _fail("no hint after one defeat")
	var tip := game.defeat_tip()
	if not tip.contains("Совет") or not tip.contains("Перекат"):
		return _fail("a hint after the second defeat: " + tip)
	# Unspent points show on the experience bar.
	hero.add_experience(hero.experience_to_next)
	game._refresh_hud()
	if not game.hud.action_bar.xp_label.text.contains("✦"):
		return _fail("unspent points are shown: " + game.hud.action_bar.xp_label.text)
	print("KEYSTONES OK")
	quit()
