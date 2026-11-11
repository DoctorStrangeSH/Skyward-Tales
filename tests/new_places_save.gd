extends SceneTree

## Stage 21 polish: a game saved inside each new place loads back into it
## with its objects; ways in and out show on the minimap; rooms sound calm.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("NEW PLACES FAILED: " + reason)
	quit(1)

func _objects(game: SkywardGame) -> int:
	var count := 0
	for node in game.get_children():
		if node is TowerObject and not node.is_queued_for_deletion():
			count += 1
	return count

func _gate_labels(game: SkywardGame) -> String:
	var text := ""
	for marker in game.minimap_markers():
		if str(marker.get("kind", "")) == "gate":
			text += str(marker.get("label", "")) + "|"
	return text

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.settlement.buildings["home"] = 1

	var labels := _gate_labels(game)
	for word in ["Башня испытаний", "Дом лесничих", "Старая штольня", "Старая цистерна"]:
		if not labels.contains(word):
			return _fail("the minimap shows the way to: %s (%s)" % [word, labels])

	var places := {
		"trial_tower": Vector2(272, 322), "flooded_cistern": Vector2(216, 700), "guild_lodge": Vector2(320, 270),
		"old_adit": Vector2(110, 500), "hero_home": Vector2(320, 260),
	}
	for region in places:
		if region == "trial_tower":
			game.trials.enter(1)
		else:
			game._travel(str(region), places[region])
		await process_frame
		await process_frame
		var before := _objects(game)
		if before < 5:
			return _fail("%s is furnished: %d" % [region, before])
		var snapshot: Dictionary = game.make_save_snapshot()
		game._travel("greenreach", Vector2(600, 600))
		await process_frame
		await process_frame
		if not game.restore_save_snapshot(snapshot):
			return _fail("a save made in %s loads" % region)
		await process_frame
		await process_frame
		if game.current_region != str(region) or _objects(game) != before:
			return _fail("%s comes back whole: %d of %d" % [region, _objects(game), before])
		if region != "trial_tower" and region != "flooded_cistern" and not _gate_labels(game).contains("Выход"):
			return _fail("%s shows the way out" % region)
		if game.is_indoors() != (region in ["guild_lodge", "hero_home"]):
			return _fail("rooms are indoors: " + str(region))
		if game.is_indoors() and (GameAudio.instance().current_track != "night" or game.ambience_for(str(region), false) != "fire"):
			return _fail("a room sounds calm: " + GameAudio.instance().current_track)

	# Blessings stop at three stacks.
	var tower := game.trials
	tower.blessings = {"might": 3, "guard": 3, "haste": 3, "focus": 3}
	tower.state = "fight"
	tower._on_cleared()
	if tower.offered != ["vigor"]:
		return _fail("only blessings below the cap are offered: " + str(tower.offered))
	tower.floor_no = 30
	if tower.health_mult() <= 0.7 + 0.16 * 29.0:
		return _fail("the climb steepens past floor 20")
	print("NEW PLACES OK")
	quit(0)
