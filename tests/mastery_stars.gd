extends SceneTree

## Этап 24: past level 20 every level gives a mastery star for a small,
## lasting bonus; the skill tree offers them; they survive a save.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("MASTERY STARS FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var stars := game.stars
	hero.level = 20
	if stars.available() != 0 or stars.spend("might"):
		return _fail("no stars at level 20")
	hero.add_experience(hero.experience_to_next)
	hero.add_experience(hero.experience_to_next)
	hero.add_experience(hero.experience_to_next)
	if hero.level != 23 or stars.available() != 3:
		return _fail("three levels past 20 — three stars (level %d, %d)" % [hero.level, stars.available()])
	var health := hero.max_health
	var reduction := hero.get_damage_reduction()
	var gold := hero.get_gold_multiplier()
	if not stars.spend("might") or not stars.spend("vigor") or not stars.spend("guard"):
		return _fail("stars are spent")
	if stars.spend("fortune"):
		return _fail("no fourth star")
	if absf(stars.melee_mult() - 1.01) > 0.0001 or hero.max_health != health + 8 or absf(hero.get_damage_reduction() - reduction - 0.01) > 0.0001:
		return _fail("bonuses apply")
	if absf(hero.get_gold_multiplier() - gold) > 0.0001:
		return _fail("fortune untouched")
	# The skill tree shows them and offers the free ones.
	hero.add_experience(hero.experience_to_next)
	for tier in Keystones.TIERS:
		hero.keystones[str(tier)] = str(Keystones.TIERS[tier]["ids"][0])
	var panel: Node = game.hud.skills_view
	panel.populate(hero)
	if not str(panel.keystone_line.text).contains("Звёзды мастерства: 1") or not panel.keystone_button.visible or not str(panel.keystone_button.text).contains("★"):
		return _fail("the tree offers the star: %s / %s" % [panel.keystone_line.text, panel.keystone_button.text])
	stars.offer()
	game.dialogues.handle_choice("star:fortune")
	if stars.rank("fortune") != 1 or stars.available() != 0:
		return _fail("a star spent from the dialogue")
	var snapshot := game.make_save_snapshot()
	hero.stars.clear()
	if not game.restore_save_snapshot(snapshot) or game.player.stars.get("might", 0) != 1 or game.stars.spent() != 4:
		return _fail("stars survive a save")
	print("MASTERY STARS OK")
	quit()
