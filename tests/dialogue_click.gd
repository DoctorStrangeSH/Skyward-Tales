extends SceneTree

## Regression: a mouse click on a dialogue choice must reach the button (the
## spell-cast click handler used to swallow every left click), and a click on
## the world must still swing the sword.
## Needs a real window: CI runs it under xvfb-run (godot-validation.yml);
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/dialogue_click.gd
## In a headless run it reports SKIPPED.
func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("DIALOGUE CLICK TEST FAILED: " + reason)
	quit(1)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("DIALOGUE CLICK SKIPPED: needs a window (xvfb-run)")
		quit(0)
		return
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	# Alaya's dialogue: the first choice starts her trail.
	game.scout.talk("scout")
	for i in 10:
		await process_frame
	var box := game.hud.dialogue_choices_container
	if box.get_child_count() == 0:
		return _fail("the dialogue shows choices")
	var button: Button = box.get_child(0)
	# Window pixels per viewport pixel.
	var scale := Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	await _click(button.get_global_rect().get_center() * scale)
	if not game.scout.running:
		return _fail("clicking a choice did nothing")
	if game.attack_cooldown > 0.0:
		return _fail("the click on a button also swung the sword")
	# A click on the world swings the sword.
	for i in 10:
		await process_frame
	await _click(Vector2(250, 150) * scale)
	if game.attack_cooldown <= 0.0:
		return _fail("clicking the world no longer swings the sword")
	print("DIALOGUE CLICK OK: choices are clickable, world clicks still swing the sword")
	quit(0)
