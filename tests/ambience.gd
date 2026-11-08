extends SceneTree

## Ambient beds per land and day time, the ambience volume setting and the
## click on every button (tech debt from Этап 6).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("AMBIENCE TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var expected := {"greenreach": "birds", "crystal_caves": "cave", "salt_coast": "waves", "sky_island": "wind", "ashen_waste": "fire"}
	for region_id in expected:
		if game.ambience_for(region_id, false) != expected[region_id]:
			return _fail("%s → %s" % [region_id, game.ambience_for(region_id, false)])
	if game.ambience_for("greenreach", true) != "night":
		return _fail("crickets at night")
	for bed in ["wind", "waves", "birds", "night", "cave", "fire"]:
		if not ResourceLoader.exists("res://assets/audio/ambience/%s.ogg" % bed):
			return _fail("missing bed " + bed)
	game._travel("salt_coast", Vector2(900, 600))
	await process_frame
	await process_frame
	var audio := GameAudio.instance()
	if audio == null or audio.current_ambience != "waves":
		return _fail("the coast sounds of waves (%s)" % (audio.current_ambience if audio != null else "no audio"))
	if AudioServer.get_bus_index("Ambience") == -1 or not GameSettings.DEFAULTS.has("ambience_volume"):
		return _fail("ambience bus and setting")
	var button := Button.new()
	root.add_child(button)
	if button.pressed.get_connections().is_empty():
		return _fail("buttons click")
	print("AMBIENCE TEST PASSED")
	quit(0)
