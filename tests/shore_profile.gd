extends SceneTree

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	var terrain: Dictionary = data["greenreach"]["terrain"]
	var size := Vector2(1920, 1280)
	var coast := ShoreProfile.points(terrain)
	if coast.size() < 3 or coast.size() > ShoreProfile.MAX_POINTS:
		return _fail("the authored contour fits the shader")
	for i in range(coast.size()):
		if coast[i].y < 1200 or coast[i].y > size.y or (i > 0 and coast[i].x <= coast[i - 1].x):
			return _fail("ordered coast remains inside its shallow authored band")
	if coast[0] != Vector2(0, 1280) or coast[-1] != size:
		return _fail("the contour meets the unchanged side cliffs")
	var walls := ShoreProfile.walls(coast, size)
	var checks := 0
	for x in range(1920):
		var sample := float(x) + 0.5
		var y := ShoreProfile.height_at(coast, sample, size.y)
		if y < size.y - 1.0:
			if not walls.any(func(r: Rect2) -> bool: return r.has_point(Vector2(sample, y + 1))):
				return _fail("coastal sky has no solid boundary")
			if walls.any(func(r: Rect2) -> bool: return r.has_point(Vector2(sample, y - 8))):
				return _fail("coastal collision takes too much dry ground")
		checks += 1
	for center in [200.0, 1556.0]:
		var radius := 64 if center == 200 else 40
		for x in range(int(center) - radius, int(center) + radius + 1):
			if ShoreProfile.height_at(coast, x, size.y) != size.y:
				return _fail("bridge landing or lake mouth moved")
	for tree in terrain["trees"]:
		var foot := Vector2(float(tree[0]), float(tree[1]) + 10)
		if foot.y + 8 > ShoreProfile.height_at(coast, foot.x, size.y):
			return _fail("an existing tree loses its ground")
	if not ShoreProfile.walls(PackedVector2Array(), size).is_empty():
		return _fail("other regions keep their current boundary")
	if ShoreProfile.height_at(PackedVector2Array(), 100, 1280) != 1280:
		return _fail("legacy flat boundary fallback")
	var thumb := Image.create(640, 426, false, Image.FORMAT_RGBA8)
	thumb.fill(Color.WHITE)
	ShoreProfile.clip_thumbnail(thumb, coast, size)
	for x in thumb.get_width():
		var edge := ShoreProfile.height_at(coast, (float(x) + 0.5) * size.x / 640.0, size.y)
		for y in range(400, 426):
			var solid := (float(y) + 0.5) * size.y / 426.0 <= edge
			if (thumb.get_pixel(x, y).a > 0.0) != solid:
				return _fail("thumbnail coastline differs from the world")
	print("SHORE PROFILE OK: ", checks, " columns, bridge, outlet, trees and legacy regions")
	quit(0)

func _fail(reason: String) -> void:
	push_error("SHORE PROFILE FAILED: " + reason)
	quit(1)
