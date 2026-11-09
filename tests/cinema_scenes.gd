extends SceneTree

## Stage 20: story scenes on the engine — black bars, the camera gliding
## to a point and zooming, the world darkening — and everything back to
## normal when the scene ends.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CINEMA SCENES FAILED: " + reason)
	quit(1)

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var camera := game.hero_camera()
	var base_zoom := camera.zoom

	var cinematic := 0
	for id in game.story.scenes:
		if bool(game.story.scenes[id].get("cinematic", false)):
			cinematic += 1
	if cinematic < 8:
		return _fail("key scenes are told on the engine (%d)" % cinematic)

	var steps := [
		{"text": "Раз."},
		{"effect": "camera", "to": [game.player.global_position.x + 80, game.player.global_position.y], "zoom": 1.5, "time": 0.2},
		{"effect": "fade", "to": 0.8, "time": 0.2},
		{"text": "Два."},
		{"text": "Три."},
	]
	game.story.scenes["_cine_test"] = {"cinematic": true, "steps": steps}
	game.story.play("_cine_test")
	await _wait(0.6)
	if not game.hud.letterbox_on():
		return _fail("a cinematic scene puts black bars on")
	game.story.advance()
	await _wait(0.5)
	if game.cinema_offset.distance_to(Vector2(80, 0)) > 1.0 or not camera.zoom.is_equal_approx(base_zoom * 1.5):
		return _fail("the camera glides and zooms: %s %s" % [game.cinema_offset, camera.zoom])
	if absf(camera.offset.x - 80.0) > 1.0:
		return _fail("the camera offset follows the scene")
	if game.hud.fade_rect.modulate.a < 0.75:
		return _fail("the world darkens")
	game.story.skip()
	await _wait(1.0)
	if game.story.active or game.hud.letterbox_on():
		return _fail("the bars go away with the scene")
	if game.cinema_offset.length() > 0.5 or not camera.zoom.is_equal_approx(base_zoom):
		return _fail("the camera comes back to the hero: %s %s" % [game.cinema_offset, camera.zoom])
	if game.hud.fade_rect.modulate.a > 0.05:
		return _fail("the world brightens again")

	# A plain conversation has no bars.
	game.story.play_steps(["Привет."], "elder", "Элиан")
	await _wait(0.5)
	if game.hud.letterbox_on():
		return _fail("talks are not cinematic")
	game.story.skip()

	print("CINEMA SCENES OK")
	quit(0)
