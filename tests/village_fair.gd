extends SceneTree

## Stage 20: the village fair — every fourth day the meadow south of the
## market fills with stalls; the shooting gallery and fish give tokens, the
## booth trades them for prizes; fair music; villagers dance in the evening.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("VILLAGE FAIR FAILED: " + reason)
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
	var fair := game.fair
	var hero := game.player

	# Not every day.
	var days := 0
	for d in 12:
		if VillageFair.is_fair_day(d):
			days += 1
	if days != 3:
		return _fail("a fair every fourth day")
	game.day_night.day = 1
	game.day_night.time = 0.5
	await process_frame
	if fair.open() or fair.days_until() != 1:
		return _fail("no fair on an ordinary day")
	for node in game.get_children():
		if node is VillageFair.FairStand:
			return _fail("no stalls without a fair")

	# Fair day: stalls, garlands, music, an announcement.
	game.day_night.day = 2
	await process_frame
	await process_frame
	if not fair.open_here():
		return _fail("the fair is open on day 2")
	var stands: Array = []
	for node in game.get_children():
		if node is VillageFair.FairStand:
			stands.append(node)
	if stands.size() != 2:
		return _fail("two stalls: %d" % stands.size())
	if GameAudio.instance().current_track != "fair":
		return _fail("fair music plays: " + GameAudio.instance().current_track)
	if fair.announced_day != 2:
		return _fail("the fair is announced")

	# The shooting gallery: targets pop up and can be hit.
	fair.open_gallery()
	if not _choices(game).contains("Начать"):
		return _fail("the gallery offers a round")
	game._on_dialogue_choice_selected("fair_gallery_start")
	if not fair.playing:
		return _fail("the round starts")
	for i in 5:
		var target := fair.spawn_target()
		if not VillageFair.RANGE.has_point(target.global_position):
			return _fail("targets stand on the range")
		await process_frame
		game._strike(target, 50, Vector2.RIGHT, 0.0)
	await process_frame
	if fair.score != 5:
		return _fail("hits count: %d" % fair.score)
	fair.time_left = 0.01
	await process_frame
	await process_frame
	if fair.playing or fair.tokens() != 3 or fair.best != 5:
		return _fail("5 targets → 3 tokens and a record: %d tokens" % fair.tokens())
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("fair_target") and not node.is_queued_for_deletion():
			return _fail("targets go away after the round")
	if hero.level != 1 or game.defeated_enemies != 0:
		return _fail("targets give no experience and are no kills")

	# Fish on a fair day.
	game.fishing.finished.emit("perch")
	game.fishing.finished.emit("old_boot")
	if fair.tokens() != 4:
		return _fail("a fish gives a token, a boot does not")

	# Prizes.
	fair.open_booth()
	if not _choices(game).contains("Сахарный петушок"):
		return _fail("the booth lists prizes:\n" + _choices(game))
	game._on_dialogue_choice_selected("fair_prize:0")
	if fair.tokens() != 2 or not hero.inventory.has("candy_cock"):
		return _fail("a candy cockerel for 2 tokens")
	game._on_dialogue_choice_selected("fair_prize:4")
	if hero.inventory.has("starlight_essence"):
		return _fail("not enough tokens for the essence")
	if not hero.use_item("candy_cock") or hero.buff_value("speed") <= 0.0:
		return _fail("the cockerel is sweet and fast")

	# Evening: the villagers gather at the pole; fireworks go up.
	game.day_night.time = 0.75
	if game.village.spot("elder", "evening").distance_to(VillageFair.POLE) > 60.0:
		return _fail("villagers dance around the pole")
	fair._firework_clock = 0.0
	await process_frame
	if fair._firework_clock <= 0.0:
		return _fail("fireworks go up in the evening")

	# Night: the fairground is packed away.
	game.day_night.time = 0.9
	await process_frame
	await process_frame
	for node in game.get_children():
		if node is VillageFair.FairStand and not node.is_queued_for_deletion():
			return _fail("the stalls close at night")
	if GameAudio.instance().current_track == "fair":
		return _fail("the music changes back")
	var snapshot := fair.make_snapshot()
	fair.restore_snapshot({})
	fair.restore_snapshot(snapshot)
	if fair.best != 5:
		return _fail("the record is saved")

	print("VILLAGE FAIR OK")
	quit(0)
