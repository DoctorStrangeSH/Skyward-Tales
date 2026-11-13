extends SceneTree

## Этап 24: difficulty levels — foes tougher or softer, catching up with a
## hero who outgrew the land (not in «Сказка»), rewards, saves, the setting
## for new adventures, the heroic achievement.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("DIFFICULTY FAILED: " + reason)
	quit(1)

func _foe(game: SkywardGame) -> SlimeEnemy:
	var foe := game.spawn_enemy("slime", game.player.global_position + Vector2(400, 0))
	foe.set_physics_process(false)
	return foe

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
	if game.difficulty != Difficulty.DEFAULT or Difficulty.names().size() != 4:
		return _fail("four levels, normal by default")
	var stats := {}
	for level in 4:
		game.difficulty = level
		var foe := _foe(game)
		stats[level] = [foe.max_health, foe.attack_damage, foe.xp_reward]
		foe.free()
	if not (stats[0][0] < stats[1][0] and stats[1][0] < stats[2][0] and stats[2][0] < stats[3][0]):
		return _fail("health grows with difficulty: %s" % str(stats))
	if not (stats[0][1] < stats[1][1] and stats[2][1] < stats[3][1]):
		return _fail("damage grows with difficulty: %s" % str(stats))
	if stats[2][2] <= stats[1][2]:
		return _fail("heroic pays more experience")
	# Catching up: a level-20 hero in the first land.
	while hero.level < 20:
		hero.add_experience(hero.experience_to_next)
	game.difficulty = 1
	var normal := _foe(game)
	game.difficulty = 0
	var story := _foe(game)
	if normal.max_health < stats[1][0] * 2 or story.max_health > stats[0][0] * 1.01:
		return _fail("normal foes catch up, story foes do not: %d / %d" % [normal.max_health, story.max_health])
	if normal.xp_reward <= stats[1][2]:
		return _fail("caught-up foes are worth more, not less")
	normal.free()
	story.free()
	# Gold and the setting.
	game.difficulty = 1
	var gold := hero.get_gold_multiplier()
	game.set_difficulty(3)
	if hero.get_gold_multiplier() < gold * 1.39 or Difficulty.default_level() != 3:
		return _fail("legendary pays more and becomes the setting for new games")
	game.set_difficulty(2)
	if game.lowest_difficulty != 1:
		return _fail("the lowest level played is kept")
	# Saves keep it.
	var snapshot := game.make_save_snapshot()
	game.difficulty = 0
	if not game.restore_save_snapshot(snapshot) or game.difficulty != 2:
		return _fail("the save keeps its difficulty")
	# The heroic saga needs the whole story on heroic.
	game.lowest_difficulty = 2
	game.quests.quest_completed.emit("main_heart")
	if int(game.achievements.stats.get("heroic_end", 0)) != 1 or int(game.achievements.stats.get("legendary_end", 0)) != 0:
		return _fail("the heroic saga")
	GameSettings.set_float("difficulty", 1.0)
	print("DIFFICULTY OK")
	quit()
