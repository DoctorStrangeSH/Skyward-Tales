extends SceneTree

## Owner's list №39 (package F): a tidy world. Trees stand apart and off the
## paths, nothing lives in water or walls, fishing spots are on the shore,
## houses have footpaths, and the water itself is solid (except fords and
## piers).

const WORLD := preload("res://scripts/world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("WORLD LAYOUT FAILED: " + reason)
	quit(1)

func _depth(pond: Dictionary, p: Vector2) -> float:
	if pond.has("circle"):
		var c: Array = pond["circle"]
		return float(c[2]) - Vector2(p.x - float(c[0]), (p.y - float(c[1])) * 1.08).length()
	var r: Array = pond["rect"]
	return minf(minf(p.x - float(r[0]), float(r[0]) + float(r[2]) - p.x), minf(p.y - float(r[1]), float(r[1]) + float(r[3]) - p.y))

func _in_wall(terrain: Dictionary, p: Vector2) -> bool:
	for blocker in terrain.get("blockers", []):
		var center := Vector2(blocker["center"][0], blocker["center"][1])
		var size := Vector2(blocker["size"][0], blocker["size"][1])
		if Rect2(center - size * 0.5, size).has_point(p):
			return true
	return false

func _run() -> void:
	for region_id in RegionCatalog.all_ids():
		var region := RegionCatalog.get_region(str(region_id))
		var terrain: Dictionary = region.get("terrain", {})
		var trees: Array = terrain.get("trees", [])
		for i in trees.size():
			var a := Vector2(trees[i][0], trees[i][1])
			for j in i:
				if a.distance_to(Vector2(trees[j][0], trees[j][1])) < 28.0:
					return _fail("%s: trees grow into each other at %s" % [region_id, a])
			if WORLD._near_trail(terrain.get("trails", []), a + Vector2(0, 8), 18.0):
				return _fail("%s: a tree on the path at %s" % [region_id, a])
		for key in ["npcs", "chests", "herbs", "gather", "lore", "enemies"]:
			for item in region.get(key, []):
				var p := Vector2(item["position"][0], item["position"][1])
				for pond in terrain.get("ponds", []):
					if _depth(pond, p) > 0.0:
						return _fail("%s: %s %s stands in the water at %s" % [region_id, key, str(item.get("id", item.get("kind", ""))), p])
				if _in_wall(terrain, p):
					return _fail("%s: %s %s is inside a wall at %s" % [region_id, key, str(item.get("id", item.get("kind", ""))), p])

	# The water is solid; the shore, fords and piers are not.
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var solid := func(p: Vector2) -> bool:
		return game.world._wall_rects.any(func(r: Rect2) -> bool: return r.has_point(p))
	var lake: Array = RegionCatalog.terrain("greenreach")["ponds"][0]["circle"]
	if not solid.call(Vector2(lake[0], lake[1])):
		return _fail("the lake in the Reaches is solid")
	if solid.call(Vector2(lake[0], lake[1]) + Vector2(float(lake[2]) - 4.0, 0)):
		return _fail("the very shore stays walkable for fishing")
	for i in 3:
		await physics_frame
	# Foes still find their way around the water.
	var west := Vector2(lake[0], lake[1]) - Vector2(float(lake[2]) + 30.0, 0)
	var east := Vector2(lake[0], lake[1]) + Vector2(float(lake[2]) + 30.0, 0)
	var around := NavigationServer2D.map_get_path(game.world.get_world_2d().navigation_map, west, east, true)
	if around.size() < 3 or around[around.size() - 1].distance_to(east) > 12.0:
		return _fail("a path leads around the lake (%d points)" % around.size())
	game._set_region("salt_coast", Vector2(500, 500), false)
	await process_frame
	if not solid.call(Vector2(100, 900)) or solid.call(Vector2(252, 432)):
		return _fail("the sea is solid, the pier is not")
	game._set_region("misty_marsh", Vector2(640, 100), false)
	await process_frame
	for trail in RegionCatalog.terrain("misty_marsh")["trails"]:
		for point in trail:
			if solid.call(Vector2(point[0], point[1])):
				return _fail("trails through the bog stay open (fords) at %s" % str(point))
	# Houses have footpaths to the road.
	var reach := RegionCatalog.terrain("greenreach")
	for prop in reach["props"]:
		if str(prop["kind"]).begins_with("village_house"):
			var door := Vector2(prop["position"][0], prop["position"][1] + 8)
			if not WORLD._near_trail(reach["trails"], door, 36.0):
				return _fail("a house without a path at %s" % door)
	print("WORLD LAYOUT OK")
	quit(0)
