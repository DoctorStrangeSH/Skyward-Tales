extends SceneTree

## Этап 24: the Keepers' Abode — a story dungeon with puzzles under the Sky
## Island, three seals, and the hidden home of the last Keepers.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("KEEPERS SANCTUM FAILED: " + reason)
	quit(1)

func _door(game: SkywardGame, id: String) -> DungeonDoor:
	for node in game.get_children():
		if node is DungeonDoor and node.door_id == id and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	var gate := RegionCatalog.gate("sky_island", KeepersSanctum.REGION)
	if gate.is_empty() or str(gate.get("requires_quest", "")) != "main_archive":
		return _fail("a hidden stair on the Sky Island, after the Archive")
	game._set_region("sky_island", Vector2(880, 640), false)
	for i in 14:
		await physics_frame
	var map := game.world.get_world_2d().navigation_map
	var at := SkywardGame._vec(gate["position"])
	if NavigationServer2D.map_get_closest_point(map, at).distance_to(at) > 40.0:
		return _fail("the stair on the island stands where one can walk: %s" % str(at))
	game._set_region(KeepersSanctum.REGION, Vector2(400, 1300), false)
	for i in 14:
		await physics_frame
	map = game.world.get_world_2d().navigation_map
	for id in KeepersSanctum.SEALS:
		if _door(game, id) == null or _door(game, id).is_open:
			return _fail("three closed seals: " + id)
	for spot in [Vector2(400, 1300), Vector2(330, 150), Vector2(470, 150)]:
		if NavigationServer2D.map_get_closest_point(map, spot).distance_to(spot) > 30.0:
			return _fail("one can stand at %s" % str(spot))
	for node in get_nodes_in_group("puzzle_piece"):
		var p: Vector2 = node.global_position
		if NavigationServer2D.map_get_closest_point(map, p).distance_to(p) > 30.0:
			return _fail("a puzzle stone one can reach: %s" % str(p))
	var puzzles := game.puzzles
	# The runes: wake all six (scrambled by touching 1 and 4).
	puzzles.touch("sanctum_runes", 1)
	if not puzzles.touch("sanctum_runes", 4) or not _door(game, "sanctum_runes").is_open:
		return _fail("the rune seal opens")
	# The crystals: earth, water, fire, wind.
	for index in [1, 3, 0]:
		puzzles.touch("sanctum_crystals", index)
	if not puzzles.touch("sanctum_crystals", 2) or not _door(game, "sanctum_crystals").is_open:
		return _fail("the crystal seal opens")
	# The guard hall: when the guards fall, the last seal opens.
	hero.global_position = KeepersSanctum.GUARD_HALL.get_center()
	game.sanctum._process(0.1)
	if _door(game, "sanctum_guard").is_open:
		return _fail("not while the guards stand")
	for enemy in game._living_enemies():
		enemy.take_damage(9999999)
	for i in 3:
		await process_frame
	game.sanctum._process(0.1)
	if not _door(game, "sanctum_guard").is_open or not bool(game.opened_doors.get("sanctum_guard", false)):
		return _fail("the guards fell — the seal opens")
	# The Keepers.
	if game.sanctum.marker("keeper_olva") != "quest":
		return _fail("Olva waits")
	var gold := hero.gold
	game.sanctum.talk("keeper_olva")
	if not game.sanctum.found or hero.gold < gold + 200 or int(hero.inventory.get("keeper_sigil", 0)) < 1 or not game.director.has_flag("keepers_found"):
		return _fail("the Keepers found: the reward")
	game.hud.close_dialogue()
	hero.add_item(KeepersSanctum.RELIC, 1)
	if not game.sanctum.trade("keeper_robe") or int(hero.inventory.get("keeper_robe", 0)) != 1 or game.sanctum.trade("keeper_robe"):
		return _fail("a relic for a Keeper's item")
	hero.health = 1
	if not game.sanctum.bless() or hero.health != hero.max_health or game.sanctum.bless():
		return _fail("the fire's blessing once a day")
	var xp := hero.experience
	hero.add_experience(100)
	if hero.experience - xp != 110 and hero.level == 1:
		return _fail("+10%% experience under the blessing (%d)" % (hero.experience - xp))
	# Saved: the seals stay open.
	var snapshot := game.make_save_snapshot()
	game.sanctum.found = false
	if not game.restore_save_snapshot(snapshot) or not game.sanctum.found or not bool(game.opened_doors.get("sanctum_crystals", false)):
		return _fail("the Abode survives a save")
	print("KEEPERS SANCTUM OK")
	quit()
