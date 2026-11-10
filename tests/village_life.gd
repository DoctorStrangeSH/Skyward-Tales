extends SceneTree

## Stage 21, step 7: hens and eggs, Alaya's trail, effect badges, new chests.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("VILLAGE LIFE FAILED: " + reason)
	quit(1)

func _count(game: SkywardGame, what: String) -> int:
	var count := 0
	for node in game.get_children():
		if node.is_queued_for_deletion():
			continue
		if what == "hen" and node is VillageHens.Hen:
			count += 1
		elif what == "egg" and node is WorldLoot and node.item_id == "egg":
			count += 1
		elif what == "flag" and node is ScoutTrail.Flag:
			count += 1
	return count

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var hens := game.hens
	var scout := game.scout

	# Hens come with the garden.
	if _count(game, "hen") != 0:
		return _fail("no hens without a garden")
	game.settlement.buildings["farm"] = 2
	game._travel("greenreach", Vector2(700, 960))
	await process_frame
	await process_frame
	if hens.count() != 3 or _count(game, "hen") != 3:
		return _fail("three hens at a level 2 garden: %d" % _count(game, "hen"))
	# A morning: eggs.
	await process_frame
	game.day_night.day += 1
	await process_frame
	await process_frame
	if hens.eggs_waiting != 3 or _count(game, "egg") != 3:
		return _fail("each hen lays an egg in the morning: %d" % _count(game, "egg"))
	for i in 3:
		game.day_night.day += 1
		await process_frame
	if hens.eggs_waiting != VillageHens.MAX_EGGS:
		return _fail("no more than six eggs wait")
	for node in game.get_children():
		if node is WorldLoot and node.item_id == "egg":
			node.collected.emit("egg", 1)
			break
	if hens.eggs_waiting != VillageHens.MAX_EGGS - 1 or int(hero.inventory.get("egg", 0)) != 1:
		return _fail("an egg is picked up")
	# A hen runs from the hero.
	var hen: VillageHens.Hen = null
	for node in game.get_children():
		if node is VillageHens.Hen:
			hen = node
			break
	hero.global_position = hen.global_position + Vector2(10, 0)
	var before := hen.global_position
	for i in 30:
		await process_frame
	if hen.global_position.x >= before.x:
		return _fail("the hen scurries away")
	# Omelette.
	hero.add_item("egg", 2)
	if not game.crafting.recipes_for("kitchen").has("cook_omelette"):
		return _fail("the kitchen fries omelettes")
	hero.add_item("omelette", 1)
	hero.use_item("omelette")
	if hero.buff_value("regen") <= 0.0:
		return _fail("the omelette feeds")
	if BuffBar.icon_for("regen") != "regeneration" or not ResourceLoader.exists("res://assets/ui/status/regeneration.png"):
		return _fail("effects have badges")
	if game.hud.buff_bar == null:
		return _fail("the HUD shows the badges")
	# Chests of the new art.
	for tier in ["wood", "iron", "gold"]:
		if not ResourceLoader.exists("res://assets/world_hd/props/chest_%s_closed.png" % tier):
			return _fail("chest art: " + tier)

	# Alaya and her trail.
	var alaya: WorldNpc = null
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "scout":
			alaya = node
	if alaya == null or alaya.visual == null or alaya.visual.chibi_id != "scout":
		return _fail("Alaya stands by the village in her red hood")
	game.day_night.day = 0
	alaya.interact()
	await process_frame
	game._on_dialogue_choice_selected("scout_run")
	if not scout.running or _count(game, "flag") != 5 or scout.route_index != 0:
		return _fail("the run starts with five flags")
	var gold := hero.gold
	var spots := scout.points(0)
	# Flags only count in order.
	hero.global_position = spots[2]
	await process_frame
	await process_frame
	if scout.next_flag != 0:
		return _fail("flags go in order")
	for spot in spots:
		hero.global_position = spot
		await process_frame
		await process_frame
	if scout.running or scout.runs_won != 1 or hero.gold <= gold:
		return _fail("the trail is won and paid")
	if float(scout.best.get("0", 0.0)) <= 0.0 or _count(game, "flag") != 0:
		return _fail("the record is kept, flags are gone")
	# Too slow.
	scout.start()
	scout.time = scout.time_limit(scout.route_index) + 1.0
	await process_frame
	await process_frame
	if scout.running or scout.runs_won != 1:
		return _fail("time runs out")
	# Another day — another route.
	game.day_night.day = 1
	if scout.route_today() != 1 or scout.gold_time(1) >= scout.time_limit(1):
		return _fail("routes change by day")
	var snapshot := scout.make_snapshot()
	scout.restore_snapshot({})
	scout.restore_snapshot(snapshot)
	if scout.runs_won != 1:
		return _fail("the trail is saved")
	print("VILLAGE LIFE OK")
	quit(0)
