extends SceneTree

## Этап 24: air battles — pirates on some flights, rounds of volleys and
## manoeuvres, boarding for the captain's chest, the radar to go around,
## a broken hull costs gold.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SKY BATTLE FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	var battle := game.sky_battle
	var ship := game.ship
	game.director.set_flag(SkyShip.READY_FLAG)
	game.visited_regions["haven"] = true
	var ambushes := 0
	for f in 20:
		if SkyBattle.ambush_on(f):
			ambushes += 1
	if SkyBattle.ambush_on(0) or SkyBattle.ambush_on(1) or ambushes < 4 or ambushes > 7:
		return _fail("about three flights in ten, not the first two (%d)" % ambushes)
	# A flight with pirates: no transition, the battle instead.
	ship.flights = 4
	if not ship.fly("haven") or not battle.active or battle.destination != "haven":
		return _fail("pirates meet the flight")
	if not game.get_children().filter(func(n: Node) -> bool: return n is FlightTransition).is_empty():
		return _fail("the flight waits for the battle")
	# Volleys until they sink.
	var hull := battle.hull
	var result := ""
	battle.rng.seed = 3
	for i in 30:
		result = battle.act("volley")
		if result != "":
			break
	if result != "won" or battle.hull >= hull or battle.won != 1:
		return _fail("volleys sink them, ours takes hits: %s" % result)
	for i in 3:
		await process_frame
	if game.current_region != "haven":
		return _fail("the flight goes on after the battle")
	game.hud.close_dialogue()
	# The manoeuvre: their next volley misses.
	battle.start("haven")
	hull = battle.hull
	battle.act("evade")
	if battle.hull != hull:
		return _fail("the manoeuvre dodges")
	# Boarding: below 40% — the boarders follow to the landing.
	battle.enemy_hp = 10
	game.dialogues.handle_choice("sky_board")
	for i in 3:
		await process_frame
	if game.current_region != SkyBattle.DECK or battle._boarders.size() != SkyBattle.BOARDERS.size():
		return _fail("the fight moves onto the deck: %s, %d" % [game.current_region, battle._boarders.size()])
	var deck := Rect2(144, 128, 512, 224)
	for foe in battle._boarders:
		var p: Vector2 = (foe as Node2D).global_position
		if not deck.has_point(p):
			return _fail("boarders stand on the deck: %s" % str(p))
	var gold := hero.gold
	for foe in battle._boarders:
		(foe as SlimeEnemy).take_damage(9999999)
	for i in 3:
		await process_frame
	if battle._boarding or hero.gold <= gold or battle.won != 2:
		return _fail("beaten boarders — the captain's chest")
	await create_timer(2.8).timeout
	await process_frame
	if game.current_region != "haven":
		return _fail("the ship flies on after the deck is clear: " + game.current_region)
	game.hud.close_dialogue()
	# Lost: the hull breaks, they take gold.
	battle.start("haven")
	hero.gold = 1000
	battle.hull = 1
	battle.enemy_hp = 9999
	if battle.act("volley") != "lost" or hero.gold != 850:
		return _fail("a broken hull costs 15%% of the gold (%d)" % hero.gold)
	for i in 3:
		await process_frame
	game.hud.close_dialogue()
	# The radar: go around.
	game.director.set_flag(SkyShip.RADAR)
	game._set_region("salt_coast", Vector2(600, 600), false)
	battle.start("haven")
	game.dialogues.handle_choice("sky_around")
	for i in 3:
		await process_frame
	if battle.active or game.current_region != "haven":
		return _fail("around them with the radar")
	print("SKY BATTLE OK")
	quit()
