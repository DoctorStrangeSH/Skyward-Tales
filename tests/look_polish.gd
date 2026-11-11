extends SceneTree

## Stage 21, step 12: the look — the camera stands back (art is shown almost
## pixel for pixel), rooms and dungeons stay closer, small lands are centred;
## painted cliffs on the southern rim; cast shadows.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("LOOK POLISH FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	GameSettings.set_bool("close_camera", false)
	game.apply_camera()
	var camera := game.hero_camera()
	if not is_equal_approx(camera.zoom.x, 0.75):
		return _fail("the camera stands back outdoors: %s" % camera.zoom)
	var size: Vector2 = game.world.map_size()
	if camera.limit_right - camera.limit_left < 853 or camera.limit_left > 0:
		return _fail("limits follow the land")
	# The rim and the shadows.
	var rim := game.world.get_node_or_null("CliffRim")
	if rim == null or rim.get_child_count() < 12:
		return _fail("painted cliffs line the southern rim")
	if camera.limit_bottom > int(size.y) + 78:
		return _fail("the camera does not look under the cliffs")
	if game.world.shadows._casts.size() < 100:
		return _fail("trees and houses cast shadows: %d" % game.world.shadows._casts.size())
	# A room: closer, centred.
	game.forestry.enter()
	await process_frame
	await process_frame
	if not is_equal_approx(camera.zoom.x, 1.25):
		return _fail("rooms are seen closer: %s" % camera.zoom)
	game.trials.enter(1)
	await process_frame
	await process_frame
	if not is_equal_approx(camera.zoom.x, 1.0):
		return _fail("dungeons at 1.0: %s" % camera.zoom)
	size = game.world.map_size()
	var seen := Vector2(640, 360) / camera.zoom.x
	if camera.limit_right - camera.limit_left < int(seen.x) or camera.limit_bottom - camera.limit_top < int(seen.y):
		return _fail("a small land is centred on the screen")
	var middle := (camera.limit_left + camera.limit_right) * 0.5
	if absf(middle - size.x * 0.5) > 2.0:
		return _fail("…around its middle: %.0f" % middle)
	if game.world.get_node_or_null("CliffRim") != null:
		return _fail("no cliffs underground")
	# The player's choice.
	GameSettings.set_bool("close_camera", true)
	game.apply_camera()
	if not is_equal_approx(camera.zoom.x, 1.5):
		return _fail("the close camera setting")
	GameSettings.set_bool("close_camera", false)
	game.apply_camera()
	print("LOOK POLISH OK")
	quit(0)
