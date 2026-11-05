extends SceneTree

## The living village (daily routines, sleep, the night guard, evening
## rumors) and a world event with consequences (the caravan → trade route
## at Bran's, or higher prices when it is lost).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("LIVING WORLD TEST FAILED: " + reason)
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
	var village: VillageLife = game.village
	var elder := _npc(game, "elder")

	# Day: everyone at work.
	game.day_night.time = 0.5
	village.on_region_ready()
	if village.phase != "day" or not elder.global_position.is_equal_approx(village.work_spot("elder")) or elder.asleep:
		return _fail("by day the elder is at the hall")

	# Dusk: walking to the square, chatting there.
	game.day_night.time = 0.78
	village._process(0.016)
	if village.phase != "evening" or not elder.is_walking():
		return _fail("at dusk villagers walk to the square")
	village.on_region_ready()
	if not elder.global_position.is_equal_approx(village.spot("elder", "evening")):
		return _fail("evening spot")
	village._chatter_clock = 0.0
	village._process(0.016)
	var chatting := village.villagers().filter(func(n: WorldNpc) -> bool: return not n.bubble_text.is_empty())
	if chatting.is_empty():
		return _fail("villagers swap rumors in the evening")

	# Night: asleep indoors, the guard walks the lamps.
	game.day_night.time = 0.9
	village.on_region_ready()
	village._process(0.016)
	if not elder.asleep or not elder.global_position.is_equal_approx(village.spot("elder", "night")):
		return _fail("at night the elder sleeps at home")
	if game._interaction_prompt(elder) != "E — постучать":
		return _fail("knock on a sleeping villager's door")
	if village.guard == null or not village.guard.is_walking():
		return _fail("the night guard patrols")
	elder.interact()
	if not game.hud.dialogue_visible:
		return _fail("a sleeping villager still answers")
	game.hud.close_dialogue()
	game.day_night.time = 0.3
	village._process(0.016)
	await process_frame
	if village.guard != null and is_instance_valid(village.guard) and not village.guard.is_queued_for_deletion():
		return _fail("the guard goes off duty in the morning")
	var smith := _npc(game, "merchant")
	if elder.asleep or smith.asleep or not smith.is_walking():
		return _fail("in the morning villagers go back to work")

	# Days pass.
	game.day_night.paused = false
	var day := game.day_night.day
	game.day_night.time = 0.9999
	game.day_night._process(1.0)
	game.day_night.paused = true
	if game.day_night.day != day + 1:
		return _fail("the day counter grows")

	# Caravan rescued → trade route.
	game.player.max_health = 99999
	game.player.health = 99999
	game._set_region("salt_coast", Vector2(400, 600), false)
	await process_frame
	game.events.start("caravan")
	var caravan: Caravan = null
	for node in game.get_children():
		if node is Caravan:
			caravan = node
	if caravan == null or caravan.attackers.size() != 4:
		return _fail("the caravan is attacked by four monsters")
	for enemy in caravan.attackers.duplicate():
		(enemy as SlimeEnemy).take_damage(999999)
	await process_frame
	if caravan.state != "saved" or not game.world_state.has("trade_route") or game.world_state.days_left("trade_route") != 3:
		return _fail("a rescued caravan opens the trade route for 3 days")
	if game.achievements.progress("caravan_1") != 1:
		return _fail("caravan achievement")
	game._set_region("greenreach", Vector2(700, 700), false)
	await process_frame
	game.dialogues.on_merchant()
	var shop := game.merchant_shop
	if not shop.caravan_open or shop.get_price("health_potion", 0) != 16 or shop.get_price("treasure_map", 0) <= 0:
		return _fail("Bran sells caravan goods with 10% off")
	game.hud.close_dialogue()
	var found_news := false
	for i in 40:
		if village.rumor().contains("Караван"):
			found_news = true
			break
	if not found_news:
		return _fail("villagers gossip about the caravan")

	# Lost caravan → prices rise.
	game.world_state.clear("trade_route")
	game._set_region("salt_coast", Vector2(400, 600), false)
	await process_frame
	game.events.start("caravan")
	for node in game.get_children():
		if node is Caravan:
			caravan = node
	caravan.time_left = 0.01
	caravan._process(0.1)
	if caravan.state != "lost" or not game.world_state.has("caravan_lost"):
		return _fail("a lost caravan raises prices")
	game.dialogues.on_merchant()
	if shop.caravan_open or shop.get_price("health_potion", 0) != 20:
		return _fail("prices +15%% after the loss: %d" % shop.get_price("health_potion", 0))
	game.hud.close_dialogue()

	# Saved with the game.
	var snapshot := game.world_state.make_snapshot()
	game.world_state.states.clear()
	game.world_state.restore_snapshot(snapshot)
	if not game.world_state.has("caravan_lost"):
		return _fail("world states are saved")
	print("LIVING WORLD OK: routines, sleep, guard, rumors, days, caravan, market")
	quit(0)
