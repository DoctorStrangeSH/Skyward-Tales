extends SceneTree

## Sword combat: LMB slashes in front (two-step combo), holding charges a
## full-circle spin at 1.8x damage, blades add damage; in a new story the
## heroine starts with a sword and magic stays asleep until the guardian.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SWORD TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	hero.global_position = Vector2(1300, 700)
	hero.facing = Vector2.RIGHT
	var front: SlimeEnemy = game.spawn_enemy("slime", hero.global_position + Vector2(20, 0))
	var behind: SlimeEnemy = game.spawn_enemy("slime", hero.global_position + Vector2(-20, 0))
	front.set_physics_process(false)
	behind.set_physics_process(false)
	var front_hp := front.health
	var behind_hp := behind.health
	game._aim_direction()
	if not game.sword_slash():
		return _fail("a slash happens")
	if front.health >= front_hp or behind.health != behind_hp:
		return _fail("a slash hits only in front")
	if not hero.visual.is_playing_action() or hero.visual.hframes != 6:
		return _fail("the slash animation plays")
	if game.sword_slash():
		return _fail("slashes have a short cooldown")
	game.attack_cooldown = 0.0
	if game._combo_step != 1:
		return _fail("the second slash continues the combo")
	behind_hp = behind.health
	game.attack_cooldown = 0.0
	game.sword_spin()
	if behind.health >= behind_hp:
		return _fail("the spin hits all around")
	var base := hero.get_melee_damage()
	hero.add_item("iron_sword")
	hero.equip_item("iron_sword")
	if hero.get_melee_damage() != base + 8:
		return _fail("blades add sword damage")
	game.queue_free()
	await process_frame

	# A new story: sword in hand, magic asleep.
	set_meta("skyward_new_hero", {"name": "Арина", "gender": "f"})
	var story: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(story)
	await process_frame
	story.autosave_enabled = false
	if story.player.equipment.get("blade", "") != "traveler_sword":
		return _fail("the heroine starts with the traveler's sword")
	if story.magic_unlocked():
		return _fail("magic is asleep at the start")
	var mana := story.player.mana
	story._cast_spell()
	if story.player.mana != mana:
		return _fail("no spells before the awakening")
	story.quests.start_quest("main_guardian")
	story.quests.add_progress("main_guardian", 1)
	story.quests.complete_quest("main_guardian")
	if not story.magic_unlocked():
		return _fail("the guardian's fall awakens magic")
	print("SWORD OK: slash arc, cooldown, combo, spin, blades, starting sword, magic awakening")
	quit(0)
