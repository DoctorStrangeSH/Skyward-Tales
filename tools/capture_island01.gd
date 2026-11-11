extends SceneTree

## Capture the actual game at fixed midday, not a reconstructed mockup.
func _initialize() -> void:
	call_deferred("_run")

func _hide_title(game: SkywardGame) -> void:
	if is_instance_valid(game.hud.title_card):
		game.hud.title_card.visible = false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if not args.is_empty() else "/project/docs/screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSettings.set_bool("color_grade", true)
	GameSettings.set_bool("hints", false)
	GameSettings.set_bool("close_camera", false)
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	game.day_night.time = 0.5
	if game.story.active:
		game.story.skip()
	game.player.set_physics_process(false)
	game.hud.set_letterbox(false)
	_hide_title(game)
	for entry in [
		["greenreach_village", Vector2(300, 620)],
		["greenreach_waterfall", Vector2(1500, 1170)]
	]:
		game.player.global_position = entry[1]
		var camera := game.hero_camera()
		camera.reset_smoothing()
		for frame in 45:
			await process_frame
		_hide_title(game)
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		var path := out_dir.path_join(str(entry[0]) + ".png")
		if screenshot.save_png(path) != OK:
			push_error("Cannot save scene capture: " + path)
			quit(1)
			return
		if str(entry[0]) == "greenreach_waterfall":
			screenshot.resize(1280, 720, Image.INTERPOLATE_NEAREST)
			if screenshot.save_png(out_dir.path_join("greenreach_preview.png")) != OK:
				quit(1)
				return
		print("Captured actual island: ", path)
	quit(0)
