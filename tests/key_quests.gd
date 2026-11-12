extends SceneTree

## Этап 23: story gates have key errands. Each keyed gate names a real quest
## or flag; the errand's pickups appear when it is taken, stand where the
## hero can walk, are pinned on the map and say whom to go back to.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("KEY QUESTS FAILED: " + reason)
	quit(1)

const ERRANDS := {"key_lower_shaft": "old_adit", "key_wind_chant": "sky_island", "key_rift_sparks": "wind_spires"}

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var director := game.director
	var keyed := 0
	for link in director.chain:
		var key: Dictionary = director.key(link)
		if key.is_empty():
			continue
		keyed += 1
		if key.has("quest") and not game.quests.definitions.has(str(key["quest"])):
			return _fail("key quest exists: %s" % str(key))
		if str(key.get("hint", "")).is_empty():
			return _fail("a key says where to look: %s" % str(link["start"]))
	if keyed < 5:
		return _fail("five gates have keys: %d" % keyed)
	for quest_id in ERRANDS:
		var region: String = ERRANDS[quest_id]
		game.quests.start_quest(quest_id)
		var gates: Array = RegionCatalog.get_region(region).get("gates", [])
		game._travel(region, SkywardGame._vec(gates[0].get("position")) + Vector2(0, 30) if not gates.is_empty() else OldAdit.INSIDE)
		for i in 12:
			await physics_frame
		var found: Array = []
		for node in game.get_children():
			if node is WorldCollectible and node.quest_id == quest_id and not node.is_queued_for_deletion():
				found.append(node)
		var target := int(game.quests.definitions[quest_id]["target"])
		if found.size() != target:
			return _fail("%s: %d pickups in %s" % [quest_id, found.size(), region])
		var map := game.world.get_world_2d().navigation_map
		for node in found:
			var spot: Vector2 = (node as Node2D).global_position
			if NavigationServer2D.map_get_closest_point(map, spot).distance_to(spot) > 14.0:
				return _fail("%s: pickup at %s is out of reach" % [quest_id, str(spot)])
		game.quest_nav.refresh()
		var pinned := game.quest_nav.targets.filter(func(t: Dictionary) -> bool: return str(t["region"]) == region and t["position"] is Vector2 and str(t["title"]) == str(game.quests.definitions[quest_id]["title"]))
		if pinned.size() != target:
			return _fail("%s pinned on the map: %d" % [quest_id, pinned.size()])
		for node in found:
			game.pickups.handle(node)
		if not game.quests.is_ready_to_complete(quest_id):
			return _fail("%s is ready after the pickups" % quest_id)
		game.quests.complete_quest(quest_id)
	if not game.pickups.return_line("key_lower_shaft").contains("Дорн"):
		return _fail("the key goes back to Dorn: " + game.pickups.return_line("key_lower_shaft"))
	# An early visit to the Sky Heart does not burn the ascent's arrival.
	game.quests.states["main_prologue"]["started"] = true
	game.director.on_region_entered("sky_heart")
	if game.director.has_flag("arrived_heart"):
		return _fail("an early visit leaves the arrival for later")
	game.director.set_flag("arrived_heart")
	game.quests.start_quest("main_ascent")
	game.director.on_region_entered("sky_heart")
	if not game.quests.is_completed("main_ascent"):
		return _fail("a save with a burnt arrival finishes the ascent on entry")
	print("KEY QUESTS OK")
	quit()
