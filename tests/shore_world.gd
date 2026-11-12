extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	await process_frame
	var terrain: Dictionary = RegionCatalog.terrain("greenreach")
	var coast := ShoreProfile.points(terrain)
	var ground := world.get_node("GroundHD") as Sprite2D
	if ground.material == null or int(ground.material.get_shader_parameter("shore_count")) != coast.size():
		return _fail(world, "the actual ground uses the authored profile")
	if world.get_node_or_null("ShoreSky") == null:
		return _fail(world, "the inlets reveal sky rather than the clear colour")
	var faces := 0
	for child in world.get_node("CliffRim").get_children():
		if child is Sprite2D and child.z_index == 0:
			faces += 1
			if child.material == null or int(child.material.get_shader_parameter("shore_count")) != coast.size():
				return _fail(world, "a cliff module still follows the rectangular shore")
	if faces < 8:
		return _fail(world, "cliff coverage is missing")
	for x in [360, 744, 1032, 1224, 1408, 1680, 1840]:
		var edge := ShoreProfile.height_at(coast, x, 1280)
		if not world._wall_rects.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(x + 0.5, edge + 8))):
			return _fail(world, "the actual world lets actors into a coastal inlet")
	if world.navigation == null or world.navigation.navigation_polygon.get_polygon_count() == 0:
		return _fail(world, "the coastal collision did not bake into navigation")
	var map := WorldMinimap.new()
	map.update_map("greenreach", Vector2(960, 1200), {})
	var texture := map._texture()
	var image := texture.get_image()
	var sample := Vector2i(int(1224.0 / 1920.0 * image.get_width()), image.get_height() - 2)
	if image.get_pixelv(sample).a > 0.0:
		map.free()
		return _fail(world, "the live minimap still shows rectangular land")
	map.free()
	world.queue_free()
	for frame in 4:
		await process_frame
	print("SHORE WORLD OK: ground, cliff modules, sky, collisions, navigation and live map")
	quit(0)

func _fail(world: Node, reason: String) -> void:
	world.queue_free()
	push_error("SHORE WORLD FAILED: " + reason)
	quit(1)
