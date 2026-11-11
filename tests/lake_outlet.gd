extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("LAKE OUTLET FAILED: " + reason)
	quit(1)

func _run() -> void:
	var world = load("res://scripts/world.gd").new()
	var terrain: Dictionary = RegionCatalog.get_region("greenreach")["terrain"]
	var channel: Dictionary = {}
	for pond in terrain["ponds"]:
		if pond.get("id", "") == "east_lake_outlet":
			channel = pond
	if channel.is_empty():
		world.free()
		return _fail("the lake has an authored outlet")
	# No dry interval between the lake and the falling stream.
	for y in range(1050, 1280, 2):
		var wet := false
		for pond in terrain["ponds"]:
			wet = wet or world._deep_water(pond, Vector2(1556, y))
		if not wet:
			world.free()
			return _fail("dry break at y=%d" % y)
	world.terrain = {"ponds": [channel]}
	world._add_water_walls()
	for point in [Vector2(1556, 1140), Vector2(1556, 1210), Vector2(1556, 1260)]:
		if not world._wall_rects.any(func(rect: Rect2) -> bool: return rect.has_point(point)):
			world.free()
			return _fail("walking and navigation must block the stream")
	for point in [Vector2(1500, 1180), Vector2(1620, 1180)]:
		if world._deep_water(channel, point) or world._wall_rects.any(func(rect: Rect2) -> bool: return rect.has_point(point)):
			world.free()
			return _fail("dry banks stay walkable")
	world.free()
	var source: Node2D = load("res://scenes/regions/greenreach_waterfalls.tscn").instantiate()
	var fall := source.get_node("EastLakeSource") as IslandWaterfall
	for dx in [-20, 0, 20]:
		var sample := fall.position + Vector2(dx, -4)
		var check = load("res://scripts/world.gd").new()
		var wet: bool = check._deep_water(channel, sample)
		check.free()
		if not wet:
			source.free()
			return _fail("water must feed the whole waterfall mouth")
	source.free()
	var rim := CliffRim.new()
	rim.setup(Vector2(1920, 1280), "greenreach", [], [], null, true)
	var depths: Array[float] = []
	for child in rim.get_children():
		if child is Sprite2D and child.z_index == 0:
			if not is_equal_approx(child.position.y + CliffRim.LIP * child.scale.y * 2.0, 1280.0):
				rim.free()
				return _fail("varied cliff faces stay joined to the ground")
			depths.append(child.scale.y)
	if depths.max() - depths.min() < 0.1:
		rim.free()
		return _fail("the lower cliff silhouette needs different depths")
	rim.free()
	print("LAKE OUTLET OK: continuous water, solid channel, walkable banks, anchored cliffs")
	quit(0)
