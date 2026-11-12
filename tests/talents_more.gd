extends SceneTree

## Этап 23: more talents with mechanics, not only numbers; the skill tree
## shows them; a reset needs a Book of Forgetting.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("TALENTS MORE FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	var defs := SkillTree.definitions()
	if defs.size() < 34:
		return _fail("34 talents at least: %d" % defs.size())
	for id in defs:
		var req: Dictionary = defs[id].get("requires", {})
		for need in req:
			if not defs.has(need):
				return _fail("%s requires a real talent" % id)
	while hero.level < 15:
		hero.add_experience(hero.experience_to_next)
	# Light step, herbalist, treasure hunter.
	var cooldown := hero.get_dodge_cooldown()
	hero.talents["light_step"] = 2
	if hero.get_dodge_cooldown() > cooldown * 0.77:
		return _fail("light step shortens the roll's cooldown")
	hero.talents["herbalist"] = 2
	hero.add_item("health_potion", 1)
	hero.health = 1
	hero.use_item("health_potion")
	if hero.health < 1 + 48:
		return _fail("herbalist potions heal more: %d" % hero.health)
	var gold := hero.get_gold_multiplier()
	hero.talents["treasure_hunter"] = 2
	if hero.get_gold_multiplier() < gold * 1.19:
		return _fail("treasure hunter")
	# Executioner and static blade.
	var foe := game.spawn_enemy("golem", hero.global_position + Vector2(400, 0))
	foe.set_physics_process(false)
	foe.health = foe.max_health
	var full := game.keystones.strike_mult(foe)
	hero.talents["executioner"] = 2
	foe.health = int(foe.max_health * 0.2)
	if game.keystones.strike_mult(foe) < full * 1.29:
		return _fail("executioner finishes the weak")
	hero.talents["static_blade"] = 1
	game.keystones.on_crit(foe)
	if foe.shock_time_left <= 0.0:
		return _fail("static blade shocks on a crit")
	# Counter: the riposte grows.
	hero.talents["counter"] = 2
	game.gear.riposte_left = 1.0
	if int(game.gear.modify_strike(10)["damage"]) != 35:
		return _fail("counter: riposte ×3.5")
	foe.free()
	# The tree shows the new talents.
	game._handle_key(KEY_T)
	await process_frame
	var text := ""
	for button in game.hud.skills_view.buttons.values():
		text += (button as Button).text + "|"
	if not text.contains("Палач") or not text.contains("Каменная стойка") or not text.contains("Лёгкий шаг"):
		return _fail("the tree shows the new talents: " + text)
	print("TALENTS MORE OK")
	quit()
