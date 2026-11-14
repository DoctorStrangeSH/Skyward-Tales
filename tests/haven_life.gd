extends SceneTree

## Этап 24: the Haven lives by the clock too — work by day, the tavern door
## in the evening, home at night with a night watchman on the lane.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("HAVEN LIFE FAILED: " + reason)
	quit(1)

func _npc(game: SkywardGame, id: String) -> WorldNpc:
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == id and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var life := game.haven_life
	if life.region() != "haven" or life.data.get("npcs", {}).size() < 8:
		return _fail("the Haven's routines are loaded")
	if game.village.region() != "greenreach":
		return _fail("the home village keeps its own")
	game.day_night.time = 0.5
	game._set_region("haven", Vector2(860, 420), false)
	for i in 14:
		await physics_frame
	var map := game.world.get_world_2d().navigation_map
	for id in life.data["npcs"]:
		for key in ["home", "evening"]:
			var at := SkywardGame._vec(life.data["npcs"][id][key])
			if NavigationServer2D.map_get_closest_point(map, at).distance_to(at) > 30.0:
				return _fail("%s's %s is somewhere one can stand: %s" % [id, key, str(at)])
	var baker := _npc(game, "haven_baker")
	if baker == null or baker.global_position.distance_to(life.work_spot("haven_baker")) > 2.0:
		return _fail("by day the baker is at work")
	# Evening: off to the tavern.
	game.day_night.time = 0.78
	for i in 3:
		await process_frame
	if life.phase != "evening" or not baker.is_walking():
		return _fail("in the evening they walk to the tavern")
	# Night: asleep at home, a watchman on the lane.
	game.day_night.time = 0.9
	life.on_region_ready()
	await process_frame
	if not baker.asleep or baker.global_position.distance_to(SkywardGame._vec(life.data["npcs"]["haven_baker"]["home"])) > 2.0:
		return _fail("at night asleep at home")
	if life.guard == null or life.guard.display_name != "Ночной дозорный Брок":
		return _fail("the night watchman")
	if life.rumor().is_empty():
		return _fail("Haven rumors")
	print("HAVEN LIFE OK")
	quit()
