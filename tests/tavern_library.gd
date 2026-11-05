extends SceneTree

## Tavern and Library: built at the board, keepers at their doors, food and
## treasure maps, hiring a sellsword (level 2), reading ancient tomes for
## skill points, the star atlas (level 2), tomes from bosses and legends.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("TAVERN TEST FAILED: " + reason)
	quit(1)

func _npc(game: SkywardGame, npc_id: String) -> WorldNpc:
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == npc_id and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	var hero := game.player
	hero.gold = 5000
	hero.add_item("wood", 60)
	hero.add_item("stone", 60)
	hero.add_item("iron_ore", 10)
	hero.add_item("wind_essence", 4)

	if _npc(game, "tavern_keeper") != null:
		return _fail("no tavern at the start")
	game.settlement.upgrade("tavern")
	await process_frame
	var greta := _npc(game, "tavern_keeper")
	if greta == null or game.buildings.level("tavern") != 1:
		return _fail("tavern built, Greta at the door")
	var houses := game.get_children().filter(func(n: Node) -> bool: return n is SettlementObject and n.art == "village_tavern_1")
	if houses.size() != 1:
		return _fail("the tavern stands")

	# Food and maps.
	greta.interact()
	game.dialogues.handle_choice("tavern_buy:bread")
	if int(hero.inventory.get("bread", 0)) != 1:
		return _fail("bread from the tavern")
	game.dialogues.handle_choice("tavern_map")
	if int(hero.inventory.get(TreasureHunt.MAP_ITEM, 0)) != 1:
		return _fail("a treasure map with a rumor")
	game.hud.close_dialogue()

	# Evening gatherings at the tavern door.
	var evening := game.village.spot("elder", "evening")
	if evening.distance_to(Vector2(680, 474)) > 80.0:
		return _fail("evenings at the tavern (%s)" % [evening])

	# Level 2: a sellsword.
	game.settlement.upgrade("tavern")
	await process_frame
	game.dialogues.handle_choice("tavern_merc")
	await process_frame
	var merc: Mercenary = null
	for node in game.get_children():
		if node is Mercenary:
			merc = node
	if merc == null or not game.world_state.has("mercenary"):
		return _fail("hire a sellsword")
	game._set_region("salt_coast", Vector2(400, 600), false)
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	await process_frame
	var count: int = game.get_children().filter(func(n: Node) -> bool: return n is Mercenary and not n.is_queued_for_deletion()).size()
	if count != 1:
		return _fail("the sellsword follows to other lands (%d)" % count)
	var wolf := game.spawn_enemy("wolf", hero.global_position + Vector2(40, 0))
	wolf.set_physics_process(false)
	var hp := wolf.health
	for i in 90:
		await physics_frame
	if is_instance_valid(wolf) and wolf.health >= hp:
		for node in game.get_children():
			if node is Mercenary:
				print("MERC ", node.global_position, " hero ", hero.global_position, " wolf ", wolf.global_position)
		return _fail("the sellsword fights")
	game.world_state.clear("mercenary")
	await physics_frame
	await process_frame
	if game.get_children().any(func(n: Node) -> bool: return n is Mercenary and not n.is_queued_for_deletion()):
		return _fail("the contract ends")

	# Library.
	game._set_region("greenreach", Vector2(500, 900), false)
	await process_frame
	game.settlement.upgrade("library")
	await process_frame
	var olwin := _npc(game, "librarian")
	if olwin == null:
		return _fail("Olwin at the library")
	hero.add_item("ancient_tome", 2)
	var points := SkillTree.available_points(hero)
	olwin.interact()
	game.dialogues.handle_choice("library_read")
	if SkillTree.available_points(hero) != points + 1 or game.buildings.tomes_read != 1:
		return _fail("a tome gives a skill point")
	game.hud.close_dialogue()
	game.settlement.upgrade("library")
	game._set_region("salt_coast", Vector2(400, 600), false)
	await process_frame
	var chests: int = game.discovered_landmarks.get("salt_coast", {}).values().filter(func(m: Dictionary) -> bool: return m["kind"] == "chest").size()
	if chests < 2:
		return _fail("the star atlas marks chests (%d)" % chests)
	if game.achievements.progress("builder_6") != 4:
		return _fail("building levels counted (%d)" % game.achievements.progress("builder_6"))

	# Tomes from legends.
	var drops_before: int = game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot and n.item_id == "ancient_tome").size()
	game.legends._on_defeated("stone_crab", Vector2(400, 600))
	var drops_after: int = game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot and n.item_id == "ancient_tome").size()
	if drops_after != drops_before + 1:
		return _fail("legends drop a tome")
	var snap := game.buildings.make_snapshot()
	game.buildings.tomes_read = 0
	game.buildings.restore_snapshot(snap)
	if game.buildings.tomes_read != 1:
		return _fail("tomes read are saved")
	print("TAVERN OK: tavern food, maps, evenings, sellsword; library tomes, atlas; tome drops")
	quit(0)
