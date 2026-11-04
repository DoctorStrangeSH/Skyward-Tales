extends SceneTree

## Variety pack: day/night cycle, treasure maps and digging, the contract
## board, the wandering trader and the meteor event.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("VARIETY TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.global_position = Vector2(1000, 760)

	# Day and night.
	var dn := game.day_night
	dn.time = 0.5
	await process_frame
	if dn.is_night() or dn.canvas.color != Color.WHITE:
		return _fail("noon is bright")
	dn.time = 0.95
	await process_frame
	if not dn.night_here() or dn.canvas.color.b <= dn.canvas.color.r:
		return _fail("night is blue")
	var day_slime: SlimeEnemy = null
	var night_slime := game.spawn_enemy("slime", Vector2(300, 300))
	dn.time = 0.5
	day_slime = game.spawn_enemy("slime", Vector2(320, 300))
	if night_slime.max_health <= day_slime.max_health:
		return _fail("night foes are tougher")
	game._set_region("crystal_caves", Vector2(400, 400), false)
	dn.time = 0.95
	await process_frame
	if dn.night_here() or dn.canvas.color != Color.WHITE:
		return _fail("caves keep their own light")
	game._set_region("greenreach", Vector2(1000, 760), false)
	dn.time = 0.5
	await process_frame

	# Treasure map.
	hero.add_item("treasure_map")
	game._on_inventory_use("treasure_map")
	if not game.treasure.has_active() or hero.inventory.has("treasure_map"):
		return _fail("reading a map marks a treasure")
	var region := str(game.treasure.active["region"])
	game._set_region(region, Vector2(400, 400), false)
	await process_frame
	var mark: DigSpot = null
	for node in game.get_children():
		if node is DigSpot:
			mark = node
	if mark == null:
		return _fail("the X appears in the right land")
	var kinds := {}
	for marker in game.treasure.minimap_marker():
		kinds[marker["kind"]] = true
	if not kinds.has("treasure"):
		return _fail("the minimap shows the treasure")
	var gold_piles := 0
	mark.interact()
	await process_frame
	for node in game.get_children():
		if node is WorldLoot and node.item_id == "gold":
			gold_piles += 1
	if game.treasure.has_active() or gold_piles < 3:
		return _fail("digging finds coins and gear")

	# Contracts.
	game._set_region("greenreach", Vector2(740, 640), false)
	await process_frame
	var board: ContractBoard = null
	for node in game.get_children():
		if node is ContractBoard:
			board = node
	if board == null:
		return _fail("the village has a contract board")
	var contracts := game.contracts
	contracts.offers = [{"id": "t1", "type": "deliver", "item": "wood", "count": 2, "progress": 0, "title": "Поставка: дерево ×2", "gold": 30, "xp": 20},
		{"id": "t2", "type": "hunt", "kind": "slime", "region": "greenreach", "count": 2, "progress": 0, "title": "Охота: слизень ×2", "gold": 40, "xp": 30}]
	board.interact()
	if not game.hud.dialogue_visible:
		return _fail("the board opens")
	game._on_dialogue_choice_selected("contract_take:0")
	game._on_dialogue_choice_selected("contract_take:0")
	if contracts.active.size() != 2:
		return _fail("two contracts can be taken")
	hero.add_item("wood", 2)
	var gold := hero.gold
	if not contracts.turn_in("t1") or hero.gold != gold + 30 or hero.inventory.has("wood"):
		return _fail("a delivery pays and takes the goods")
	game._on_enemy_defeated(5, Vector2(100, 100), "slime")
	game._on_enemy_defeated(5, Vector2(100, 100), "slime")
	if not contracts.is_ready(contracts.active[0]) or not contracts.turn_in("t2"):
		return _fail("a hunt counts kills in its land")
	game.hud.close_dialogue()

	# Trader and meteor.
	if not game.events.start("trader") or game.events.trader == null:
		return _fail("the trader arrives")
	hero.gold = 99999
	game.events.open_trader()
	var stock := game.events.trader_offers.size()
	game._on_dialogue_choice_selected("trader_buy:2")
	if game.events.trader_offers.size() != stock - 1 or not hero.inventory.has("treasure_map"):
		return _fail("buying from the trader")
	game.hud.close_dialogue()
	game.events.start("meteor")
	await create_timer(0.8).timeout
	await process_frame
	var fragments := 0
	for node in game.get_children():
		if node is WorldLoot and node.item_id == "star_fragment":
			fragments += 1
	if fragments + int(hero.inventory.get("star_fragment", 0)) < 4:
		return _fail("the meteor leaves star fragments")

	# Save keeps the new systems.
	var data := GameSaveState.capture(game)
	contracts.completed = 0
	dn.time = 0.1
	GameSaveState.apply(game, data)
	if contracts.completed != 2 or absf(dn.time - 0.5) > 0.05:
		return _fail("contracts and time of day are saved")
	print("VARIETY OK: day/night, night foes, caves, treasure map, dig, contracts, trader, meteor, save")
	quit(0)
