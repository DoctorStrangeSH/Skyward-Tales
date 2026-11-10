extends SceneTree

## Stage 21: far islands and clouds around a floating land shift with the
## camera (parallax); the hero doll in the bag shows the HD hero.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SKY PARALLAX FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var sky: SkyParallax = null
	for node in game.find_children("*", "Node2D", true, false):
		if node is SkyParallax:
			sky = node
	if sky == null:
		return _fail("the land has a sky around it")
	var islands := 0
	var left := false
	var right := false
	for item in sky.items:
		var path: String = (item["node"] as Sprite2D).texture.resource_path
		if path.contains("island") or path.contains("islet"):
			islands += 1
			var base: Vector2 = item["base"]
			left = left or base.x < 0.0
			right = right or base.x > sky._size.x
			if Rect2(Vector2.ZERO, sky._size).has_point(base):
				return _fail("islands float outside the land")
	if islands < 4 or not left or not right:
		return _fail("islands on both sides: %d" % islands)
	if sky.items.size() - islands < 8:
		return _fail("clouds drift around")
	# Parallax: a far island moves less than the camera.
	var item: Dictionary = sky.items[0]
	var node: Sprite2D = item["node"]
	game.player.global_position = Vector2(200, 300)
	game.hero_camera().reset_smoothing()
	await process_frame
	await process_frame
	var before := node.position
	game.player.global_position = Vector2(200, 700)
	game.hero_camera().reset_smoothing()
	await process_frame
	await process_frame
	var moved := node.position.distance_to(before)
	if moved < 4.0 or moved > 200.0:
		return _fail("the island shifts a little with the camera: %.1f" % moved)

	# The hero doll in the bag.
	game.input_handler.open_tab("hero")
	await process_frame
	await process_frame
	var window: InventoryWindow = game.hud.find_children("*", "InventoryWindow", true, false)[0]
	if window._portrait == null or window._portrait.region.size.x < 60.0:
		return _fail("the doll shows the HD hero")
	print("SKY PARALLAX OK")
	quit(0)
