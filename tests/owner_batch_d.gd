extends SceneTree

## Owner's list, package D: skills and passives are learned from trainers,
## companions fight with sense, grow with their own skills and gear, and
## can be talked to.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("OWNER BATCH D FAILED: " + reason)
	quit(1)

func _choices(game: SkywardGame) -> String:
	var text := ""
	for button in game.hud.dialogue_choices_container.get_children():
		text += (button as Button).text + "\n"
	return text

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	await process_frame

	# №29–30: a story hero knows only the weapon.
	hero.skills_need_learning = true
	hero.learned_skills = {}
	hero.skill_slots = ["", "", "", ""]
	if game.skills.lock_reason("lunge") != "Не изучено" or hero.has_passive("steady_hand"):
		return _fail("skills and passives wait for a trainer")
	var talked := [false]
	game.trainers.greet("blacksmith", func(_s: Variant) -> void: talked[0] = true)
	if not _choices(game).contains("Борин учит владеть клинком") or talked[0]:
		return _fail("Borin asks: talk or learn")
	game._on_dialogue_choice_selected("train_list:blacksmith")
	var lessons := _choices(game)
	if not lessons.contains("Выпад") or not lessons.contains("🔒 Сотрясение"):
		return _fail("lessons show prices and locks:\n" + lessons)
	hero.gold = 100
	game._on_dialogue_choice_selected("train_learn:blacksmith:lunge")
	if not hero.knows("lunge") or hero.gold != 80 or str(hero.skill_slots[0]) != "lunge" or not game.skills.lock_reason("lunge").is_empty():
		return _fail("a learned skill goes to the bar: %s, %d gold" % [str(hero.skill_slots), hero.gold])
	game._on_dialogue_choice_selected("train_learn:blacksmith:shockwave")
	if hero.knows("shockwave"):
		return _fail("level 3 skills wait for level 3")
	game._on_dialogue_choice_selected("train_talk:blacksmith")
	if not talked[0]:
		return _fail("«Поговорить» leads to the usual talk")
	game.hud.close_dialogue()
	hero.level = 6
	hero.gold = 1000
	game._on_dialogue_choice_selected("train_learn:grove_warden:frostbolt")
	if hero.knows("frostbolt") != false and game.director.story_mode():
		return _fail("spells wait for the awakened magic")
	game.trainers.learn("hunter", "keen_eye")
	if not hero.has_passive("keen_eye"):
		return _fail("a learned passive works at its level")
	game.hud.close_dialogue()
	hero.skills_need_learning = false

	# №18: Mira fights what the hero fights or what attacks them.
	game.ensure_companion()
	await process_frame
	var mira := game.companion
	mira.global_position = hero.global_position + Vector2(-20, 0)
	var wolf := game.spawn_enemy("wolf", hero.global_position + Vector2(120, 0))
	wolf.set_physics_process(false)
	wolf.brain_state = SlimeEnemy.BrainState.IDLE
	if mira.pick_target() != null:
		return _fail("on «Защищать» Mira leaves a quiet wolf alone")
	game.note_hero_target(wolf)
	if mira.pick_target() != wolf:
		return _fail("Mira helps with the hero's target")
	game.hero_target = null
	wolf.brain_state = SlimeEnemy.BrainState.CHASE
	if mira.pick_target() != wolf:
		return _fail("Mira shoots the wolf that hunts the hero")
	wolf.brain_state = SlimeEnemy.BrainState.IDLE
	game.crew.set_stance("cartographer", "attack")
	if mira.pick_target() != wolf:
		return _fail("on «Нападать» Mira shoots anything near")
	game.crew.set_stance("cartographer", "passive")
	game.note_hero_target(wolf)
	if mira.pick_target() != null:
		return _fail("«В стороне» — Mira does not fight")
	game.crew.set_stance("cartographer", "defend")
	# Her shots may draw a foe; at zero health she rests.
	wolf.provoke(mira)
	if wolf.taunt != mira:
		return _fail("a shot companion draws the foe")
	mira.take_damage(9999)
	if not mira.is_down() or wolf.taunt != null:
		return _fail("Mira knocked out — the foe turns away")
	mira.down_left = 0.0
	mira.health = mira.max_health

	# №19: her own level, skills and gear.
	var level := int(game.crew.state("cartographer")["level"])
	hero.add_experience(4000)
	var grown := game.crew.state("cartographer")
	if int(grown["level"]) <= level or int(grown["points"]) <= 0:
		return _fail("Mira grows with half the hero's experience")
	if not game.crew.learn("cartographer", "frost_vial") or game.crew.rank("cartographer", "frost_vial") != 1 or int(mira.ranks.get("frost_vial", 0)) != 1:
		return _fail("Mira learns her own skill")
	if not game.crew.can_learn("cartographer", "second_breath").contains("ур."):
		return _fail("Mira's late skills wait for her level")
	hero.add_item("iron_sword")
	hero.add_item("apprentice_staff")
	hero.add_item("travel_cloak")
	if game.crew.slot_for("cartographer", "iron_sword") != "":
		return _fail("Mira does not take a sword")
	var before := mira.damage_bonus
	var health_before := mira.max_health
	if not game.crew.equip("cartographer", "apprentice_staff") or not game.crew.equip("cartographer", "travel_cloak"):
		return _fail("Mira takes a staff and a cloak")
	if mira.damage_bonus <= before or mira.max_health <= health_before or hero.inventory.has("apprentice_staff"):
		return _fail("gear makes Mira stronger and leaves the bag")
	game.crew.unequip("cartographer", "armor")
	if int(hero.inventory.get("travel_cloak", 0)) != 1:
		return _fail("taking gear off returns it to the bag")

	# №21: talking to her.
	game.crew.talk("cartographer")
	var menu := _choices(game)
	if not menu.contains("Как ты?") or not menu.contains("Снаряжение и навыки") or not menu.contains("Тактика"):
		return _fail("Mira's menu:\n" + menu)
	game._on_dialogue_choice_selected("crew_chat:cartographer")
	if game.hud.dialogue_label.text.length() < 20:
		return _fail("Mira says something")
	game._on_dialogue_choice_selected("crew_stance:cartographer")
	if str(game.crew.state("cartographer")["stance"]) != "attack":
		return _fail("the menu switches tactics")
	game._on_dialogue_choice_selected("crew_page:cartographer")
	await process_frame
	if not game.hud.inventory_open or game.hud.inventory_view.tab != "party" or game.hud.inventory_view.party_view.get_child_count() < 2:
		return _fail("«Снаряжение и навыки» opens the party tab")
	game.hud.toggle_inventory(hero)

	# Saved and restored.
	var snapshot := game.make_save_snapshot()
	game.crew.members = {}
	game.restore_save_snapshot(snapshot)
	await process_frame
	if game.crew.rank("cartographer", "frost_vial") != 1 or str(game.crew.state("cartographer")["gear"]["weapon"]) != "apprentice_staff":
		return _fail("companions' growth is saved")
	if not hero.has_passive("keen_eye") or not hero.knows("lunge"):
		return _fail("learned skills are saved")

	print("OWNER BATCH D OK")
	quit(0)
