extends SceneTree

## Regression: a mouse click on a dialogue choice must reach the button (the
## spell-cast click handler used to swallow every left click).
## Run: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/dialogue_click.gd
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	# GUI picking needs a real window: run with xvfb-run (see docs/AI_HANDOFF.md).
	if DisplayServer.get_name() == "headless":
		print("DIALOGUE CLICK SKIPPED: needs a window (xvfb-run)")
		quit(0)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game._on_elder_interacted(null)
	for i in range(10): await process_frame
	var box = game.hud.dialogue_choices_container
	var b: Button = box.get_child(0)
	var r := b.get_global_rect()
	# Window pixels per viewport pixel (2 in a 1280×720 window, 1 headless).
	var scale := Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var center := r.get_center() * scale
	# What control is under the mouse at that point?
	var vp := root.get_viewport()
	var ev := InputEventMouseMotion.new(); ev.position = center; ev.global_position = center
	Input.parse_input_event(ev)
	await process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = center; e.global_position = center
		Input.parse_input_event(e)
		await process_frame
	await process_frame
	if not game.quests.is_completed("moonleaf_gathering"):
		push_error("DIALOGUE CLICK TEST FAILED: clicking a choice did nothing")
		quit(1)
		return
	var mana: int = game.player.mana
	var world_point := Vector2(450, 150) * scale
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = world_point; e.global_position = world_point
		Input.parse_input_event(e)
		await process_frame
	await process_frame
	if game.player.mana >= mana:
		push_error("DIALOGUE CLICK TEST FAILED: clicking the world no longer casts")
		quit(1)
		return
	print("DIALOGUE CLICK OK: choices are clickable, world clicks still cast")
	quit(0)
