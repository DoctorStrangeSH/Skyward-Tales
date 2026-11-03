extends SceneTree

## Captures in-game screenshots for visual review.
## Usage (needs a display, e.g. xvfb-run):
##   godot --path . --script res://tools/screenshot.gd -- <out_dir> [region] [x,y ...]
## Saves <out_dir>/<region>_<x>_<y>.png for each camera position.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://screenshots"
	var region: String = args[1] if args.size() > 1 else "greenreach"
	var points: Array[Vector2] = []
	for index in range(2, args.size()):
		var parts := args[index].split(",")
		if parts.size() == 2:
			points.append(Vector2(float(parts[0]), float(parts[1])))
	if points.is_empty():
		points.append(Vector2(250, 230))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	if region != "greenreach":
		game.quests.states["moonleaf_gathering"]["completed"] = true
		game._set_region(region, points[0], false)
	game.hud.visible = true
	for point in points:
		game.player.global_position = point
		var camera: Camera2D = game.player.get_node("Camera2D")
		camera.reset_smoothing()
		for _frame in range(20):
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%d_%d.png" % [out_dir, region, int(point.x), int(point.y)]
		image.save_png(path)
		print("saved ", path)
	quit(0)
