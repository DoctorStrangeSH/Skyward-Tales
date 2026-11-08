extends SceneTree

## Enemies path around walls (tech debt from Этап 5): every land bakes a
## navigation mesh from its walls; a foe with a wall between it and the hero
## follows the mesh instead of pressing into the wall.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("PATHFINDING TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var world := game.world
	if world.navigation == null or world.navigation.navigation_polygon.get_polygon_count() == 0:
		return _fail("the land bakes a navigation mesh")
	for i in 3:
		await physics_frame
	# A wide building (150×70 at 1715,235): the foe north of it, the hero south.
	var above := Vector2(1715, 170)
	var below := Vector2(1715, 300)
	var nav_map := world.get_world_2d().navigation_map
	var path := NavigationServer2D.map_get_path(nav_map, above, below, true)
	if path.size() < 3:
		return _fail("a path goes around the building (%d points)" % path.size())
	var foe := game.spawn_enemy("slime", above)
	foe.home_position = above
	game.player.global_position = below
	game.player.set_physics_process(false)
	await physics_frame
	game.player.set_physics_process(true)
	var dir := foe._nav_direction(below, Vector2.DOWN, 1.0)
	if dir.is_equal_approx(Vector2.DOWN) or absf(dir.x) < 0.3:
		return _fail("the foe heads around the wall, not into it (%s)" % dir)
	# Open ground: straight at the target.
	foe.global_position = Vector2(900, 700)
	foe._nav_clock = 0.0
	var straight := foe._nav_direction(Vector2(960, 700), Vector2.RIGHT, 1.0)
	if not straight.is_equal_approx(Vector2.RIGHT):
		return _fail("no detour on open ground")
	# Every land bakes a mesh.
	for region_id in ["crystal_caves", "haven", "pattern_vault", "sky_island"]:
		game._travel(region_id, Vector2(400, 400))
		await process_frame
		if game.world.navigation == null or game.world.navigation.navigation_polygon.get_polygon_count() == 0:
			return _fail("no mesh in " + region_id)
	print("PATHFINDING TEST PASSED")
	quit(0)
