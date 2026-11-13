extends SceneTree

## Этап 24: investigations — the case is taken from its giver, clues come
## from people and places, the giver hears the accusation; right and wrong
## verdicts differ and stay in the world; saves keep the case.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("MYSTERIES FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var m := game.mysteries
	if m.data.size() < 2:
		return _fail("two investigations")
	for id in m.data:
		var entry: Dictionary = m.data[id]
		if not game.quests.definitions.has(str(entry["quest"])) or not game.quests.definitions.has(str(entry["after"])):
			return _fail("%s: real quests" % id)
		if RegionCatalog.npc_name(str(entry["giver"])).is_empty():
			return _fail("%s: a real giver" % id)
		var talkers := 0
		for clue in entry["clues"]:
			if str(clue["kind"]) == "talk":
				if RegionCatalog.npc_name(str(clue["npc"])).is_empty():
					return _fail("%s: a real witness %s" % [id, clue["npc"]])
				talkers += 1
		if (entry["clues"] as Array).size() < int(entry["need"]) or not (entry["suspects"] as Array).any(func(s: Dictionary) -> bool: return str(s["id"]) == str(entry["culprit"])):
			return _fail("%s: enough clues and the culprit among suspects" % id)
	# The well: not before the moonleaves.
	if m.available("muddy_well") or m.marker("elder") != "":
		return _fail("the well waits for the first chapter")
	game.quests.states["moonleaf_gathering"]["started"] = true
	game.quests.states["moonleaf_gathering"]["completed"] = true
	hero.level = 3
	if m.marker("elder") != "quest" or not m.talk("elder"):
		return _fail("Elian offers the case")
	game._on_dialogue_choice_selected("mystery_take:muddy_well")
	if not m.is_open("muddy_well"):
		return _fail("the case is open")
	# The spot by the well and three witnesses.
	await process_frame
	var spots := get_root().get_tree().get_nodes_in_group("mystery_spot")
	if spots.size() != 1:
		return _fail("one place to look at: %d" % spots.size())
	var map := game.world.get_world_2d().navigation_map
	for i in 10:
		await physics_frame
	var spot: TowerObject = spots[0]
	if NavigationServer2D.map_get_closest_point(map, spot.global_position).distance_to(spot.global_position) > 14.0:
		return _fail("the spot can be reached")
	spot.used.emit(spot)
	game.hud.close_dialogue()
	for npc in ["alchemist", "hunter", "blacksmith"]:
		if not m.talk(npc):
			return _fail("%s gives a clue" % npc)
		game.hud.close_dialogue()
	if m.talk("alchemist"):
		return _fail("a clue once")
	if not m.ready_to_accuse("muddy_well") or m.marker("elder") != "ready" or int(game.quests.states["mystery_well"]["progress"]) != 4:
		return _fail("four clues: the accusation")
	if not m.journal_text("mystery_well").contains("торф"):
		return _fail("the journal keeps the clues")
	var snapshot := game.make_save_snapshot()
	m.cases.clear()
	if not game.restore_save_snapshot(snapshot) or game.mysteries.found("muddy_well") != 4:
		return _fail("the case survives a save")
	m = game.mysteries
	hero = game.player
	var gold := hero.gold
	m.talk("elder")
	game._on_dialogue_choice_selected("mystery_accuse:muddy_well:kai_accident")
	if not game.quests.is_completed("mystery_well") or not game.director.has_flag("mystery_muddy_well_right") or hero.gold < gold + 90:
		return _fail("the right verdict closes the case and pays")
	if m.marker("elder") != "" or m.talk("elder"):
		return _fail("the case is over")
	game.hud.close_dialogue()
	# The catch: a wrong verdict.
	game.quests.states["main_echo"]["started"] = true
	game.quests.states["main_echo"]["completed"] = true
	hero.level = 8
	m.talk("haven_fisher")
	game._on_dialogue_choice_selected("mystery_take:lost_catch")
	for npc in ["haven_child", "haven_baker", "haven_anchor", "haven_villager_a"]:
		m.talk(npc)
		game.hud.close_dialogue()
	if not m.ready_to_accuse("lost_catch"):
		return _fail("four people's words are enough")
	if m.accuse("lost_catch", "timofey") or not game.director.has_flag("mystery_lost_catch_wrong"):
		return _fail("a wrong verdict is remembered")
	# The port cargo: a late case, with places to look at in the free port.
	game.hud.close_dialogue()
	game.quests.states["main_archive"] = {"started": true, "completed": true, "progress": 1}
	hero.level = 11
	if m.marker("port_quartermaster") != "quest":
		return _fail("Bruno asks about the cargo")
	m.talk("port_quartermaster")
	game._on_dialogue_choice_selected("mystery_take:port_cargo")
	game._set_region("free_port", Vector2(640, 420), false)
	for i in 14:
		await physics_frame
	var port_map := game.world.get_world_2d().navigation_map
	var port_spots := get_nodes_in_group("mystery_spot")
	if port_spots.size() != 3:
		return _fail("three places to look at in the port, got %d" % port_spots.size())
	for place in port_spots:
		if NavigationServer2D.map_get_closest_point(port_map, place.global_position).distance_to(place.global_position) > 24.0:
			return _fail("a place one can walk to: %s" % str(place.global_position))
	for place in port_spots:
		(place as TowerObject).interact()
		game.hud.close_dialogue()
	m.talk("port_captain_vorn")
	game.hud.close_dialogue()
	if not m.ready_to_accuse("port_cargo"):
		return _fail("three places and Vorn's words are enough")
	if not m.accuse("port_cargo", "nika") or not game.director.has_flag("mystery_port_cargo_right"):
		return _fail("Nika it was")
	print("MYSTERIES OK")
	quit()
