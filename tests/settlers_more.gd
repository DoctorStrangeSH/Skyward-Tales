extends SceneTree

## Этап 24: two more settlers (beekeeper Miron, stonecutter Vilma), two more
## plots, houses that can be improved (gifts and work grow with the house).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SETTLERS FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var village := game.settlement
	if village.settlers().size() != 5 or village.free_plots().size() != 5:
		return _fail("five settlers, five plots")
	# Where they wait — somewhere one can walk.
	for id in ["beekeeper", "stonecutter"]:
		var found: Dictionary = village.settler(id)["found"]
		var stone: Variant = RegionCatalog.waystone(str(found["region"]))
		game._set_region(str(found["region"]), SkywardGame._vec(stone) + Vector2(0, 40) if stone != null else Vector2(600, 600), false)
		for i in 14:
			await physics_frame
		var at := SkywardGame._vec(found["position"])
		var map := game.world.get_world_2d().navigation_map
		if NavigationServer2D.map_get_closest_point(map, at).distance_to(at) > 30.0:
			return _fail("%s waits where one can walk: %s" % [id, str(at)])
	# Everybody housed.
	hero.gold = 99999
	hero.add_item("wood", 200)
	hero.add_item("stone", 200)
	hero.add_item("planks", 20)
	for id in village.settlers():
		village.recruited[id] = true
		if not village.build(str(id)):
			return _fail("a house for " + str(id))
	game._set_region("greenreach", Vector2(640, 600), false)
	for i in 14:
		await physics_frame
	var map := game.world.get_world_2d().navigation_map
	for plot in village.data["plots"]:
		var door := SkywardGame._vec(plot["position"]) + Vector2(0, 18)
		if NavigationServer2D.map_get_closest_point(map, door).distance_to(door) > 30.0:
			return _fail("one can reach the door at %s" % str(door))
	# The beekeeper's gift and his apiary grow with the house.
	village.gift_marks["beekeeper"] = -1
	var berries := int(hero.inventory.get("sunberry", 0))
	village._serve("beekeeper")
	if int(hero.inventory.get("sunberry", 0)) != berries + 2:
		return _fail("two berries from a plain house")
	game.hud.close_dialogue()
	if not village.upgrade_home("beekeeper") or village.home_level("beekeeper") != 2:
		return _fail("the house improved")
	village.gift_marks["beekeeper"] = -1
	berries = int(hero.inventory.get("sunberry", 0))
	village._serve("beekeeper")
	if int(hero.inventory.get("sunberry", 0)) != berries + 4:
		return _fail("a bigger house — twice the gift")
	game.hud.close_dialogue()
	game.settlement_life.collect()
	game.day_night.day += 1
	if int(game.settlement_life.store().get("sunberry", 0)) != 4:
		return _fail("the apiary works twice as hard: %s" % str(game.settlement_life.store()))
	village.upgrade_home("beekeeper")
	if village.home_level("beekeeper") != 3 or not village.home_upgrade_cost("beekeeper").is_empty():
		return _fail("level 3 is the last")
	var snapshot := game.make_save_snapshot()
	village.home_levels.clear()
	if not game.restore_save_snapshot(snapshot) or game.settlement.home_level("beekeeper") != 3:
		return _fail("house levels survive a save")
	print("SETTLERS OK")
	quit()
