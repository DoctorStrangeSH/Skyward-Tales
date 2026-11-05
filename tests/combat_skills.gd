extends SceneTree

## Hotbar skills (1–4), passives by level, new warrior talents, hero panel.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("COMBAT SKILLS TEST FAILED: " + reason)
	quit(1)

func _enemy(game: SkywardGame, at: Vector2) -> SlimeEnemy:
	var enemy: SlimeEnemy = game.spawn_enemy("slime", at)
	enemy.set_physics_process(false)
	enemy.max_health = 500
	enemy.health = 500
	return enemy

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	hero.global_position = Vector2(1300, 700)
	hero.facing = Vector2.RIGHT
	game.crit_rng.seed = 7

	# Lunge: slot 1, available from level 1, moves forward and hits the path.
	if hero.skill_slots[0] != "lunge":
		return _fail("lunge starts in slot 1")
	var target := _enemy(game, hero.global_position + Vector2(40, 0))
	var start := hero.global_position
	if not game.skills.use_slot(0):
		return _fail("lunge can be used")
	if hero.global_position.x <= start.x + 20.0 or target.health >= 500:
		return _fail("lunge dashes forward and wounds the enemy on the path")
	if game.skills.use_slot(0):
		return _fail("lunge has a cooldown")
	if game.skills.cooldown_ratio("lunge") <= 0.0:
		return _fail("the bar shows lunge cooling down")

	# Shockwave needs level 3.
	if game.skills.use("shockwave"):
		return _fail("shockwave is locked at level 1")
	while hero.level < 3:
		hero.add_experience(hero.experience_to_next)
	var near := _enemy(game, hero.global_position + Vector2(0, 30))
	if not game.skills.use("shockwave") or near.health >= 500 or near.slow_time_left <= 0.5:
		return _fail("shockwave damages and stuns around the hero")

	# War cry buffs power.
	while hero.level < 5:
		hero.add_experience(hero.experience_to_next)
	var before := hero.get_melee_damage()
	if not game.skills.use("war_cry") or hero.get_melee_damage() <= before:
		return _fail("war cry raises sword damage")

	# Blade wave reaches far ahead.
	while hero.level < 8:
		hero.add_experience(hero.experience_to_next)
	hero.facing = Vector2.RIGHT
	var far := _enemy(game, hero.global_position + Vector2(110, 0))
	if not game.skills.use("blade_wave") or far.health >= 500:
		return _fail("blade wave hits a distant enemy in front")

	# Passives switch on by level.
	if not hero.has_passive("steady_hand") or not hero.has_passive("toughness") or hero.has_passive("lifeblood"):
		return _fail("passives follow the hero's level")
	if hero.get_crit_chance() < 0.049:
		return _fail("keen eye gives crit chance")

	# Hotbar assignment swaps.
	if not hero.assign_skill(0, "war_cry") or hero.skill_slots[0] != "war_cry" or hero.skill_slots[2] != "lunge":
		return _fail("assigning a skill already on the bar swaps the slots")
	if hero.assign_skill(1, "unknown_skill"):
		return _fail("unknown skills can't go on the bar")
	var entries: Array = game.skills.hotbar_entries()
	if entries.size() != 7 or str(entries[4]["key"]) != "Пр" or int(entries[5]["count"]) < 0:
		return _fail("the bar shows four skills, dodge and potions")

	# Spells on the bar cast through the hotbar.
	hero.assign_skill(3, "frostbolt")
	var mana := hero.mana
	if not game.skills.use_slot(3) or hero.mana >= mana or game.selected_spell_id != "frostbolt":
		return _fail("a spell on the bar casts it")

	# Warrior talents.
	hero.bonus_skill_points += 3
	var armor := hero.get_armor()
	if not game.learn_skill("iron_skin") or hero.get_armor() != armor + 2:
		return _fail("iron skin adds armor")
	if not game.learn_skill("battle_rhythm") or hero.get_skill_cooldown_multiplier() >= 1.0:
		return _fail("battle rhythm shortens skill cooldowns")

	# Save and load keep the bar.
	var data := GameSaveState.capture(game)
	hero.skill_slots = ["", "", "", ""]
	GameSaveState.apply(game, data)
	if game.player.skill_slots[0] != "war_cry":
		return _fail("the bar survives save and load")

	# Hero panel (C) shows the blade slot and the skills tab.
	hero.add_item("iron_sword")
	hero.equip_item("iron_sword")
	game._handle_key(KEY_C)
	if not game.hud.hero_visible or not game.hud.inventory_view.slot_buttons.has("blade") or game.hud.inventory_view.slot_buttons["blade"].disabled:
		return _fail("C opens the hero panel with the equipped blade")
	game.hud.inventory_view.show_tab("skills")
	if not game.hud.inventory_view.skills_view.skill_rows.has("lunge") or not game.hud.inventory_view.skills_view.skill_rows.has("keen_eye"):
		return _fail("the skills tab lists actives and passives")
	game._handle_key(KEY_C)
	if game.hud.hero_visible:
		return _fail("C closes the hero panel")
	print("COMBAT SKILLS OK: lunge, shockwave, war cry, blade wave, passives, bar, spells, talents, save, hero panel")
	quit(0)
