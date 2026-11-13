extends SceneTree

## Этап 24: the settlement lives — its level, the workplaces' goods and the
## treasury on the board, settlers' daily requests.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SETTLEMENT LIFE FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var life := game.settlement_life
	var village := game.settlement
	if life.level() != 1 or life.level_name() != "Хутор" or not life.store().is_empty():
		return _fail("a hamlet with nothing on the store")
	# Two settlers housed: Yarosh and Ulf.
	hero.gold = 5000
	for id in ["woodcutter", "fisher"]:
		village.recruited[id] = true
		hero.add_item("wood", 20)
		hero.add_item("stone", 20)
		if not village.build(id):
			return _fail("a house for " + id)
	await process_frame
	if life.level() != 2 or life.celebrated_level != 2:
		return _fail("two houses: a village, celebrated (points %d)" % life.points())
	# A day of work: wood and fish wait at the store; the treasury too.
	game.day_night.day += 1
	var goods := life.store()
	if int(goods.get("wood", 0)) != 3 or int(goods.get("fish", 0)) != 2 or int(goods.get("gold", 0)) != 25:
		return _fail("a day of work: %s" % str(goods))
	game.day_night.day += 10
	if int(life.store().get("wood", 0)) != 3 * SettlementLife.MAX_DAYS:
		return _fail("the store keeps no more than three days")
	var wood := int(hero.inventory.get("wood", 0))
	if not life.collect() or int(hero.inventory.get("wood", 0)) != wood + 9 or not life.store().is_empty():
		return _fail("collected at the board: %d -> %d, left %s" % [wood, int(hero.inventory.get("wood", 0)), str(life.store())])
	# The board shows the level and offers the store.
	game.day_night.day += 1
	village.open_board()
	if not str(game.hud.dialogue_label.text).contains("Деревня"):
		return _fail("the board names the settlement level")
	game.hud.close_dialogue()
	# A request: Ulf wants something; bring it.
	var request := life.request_of("fisher")
	if request.is_empty():
		return _fail("Ulf asks for something today")
	for item in request["items"]:
		hero.add_item(str(item), int(request["items"][item]))
	if life.marker("settler_fisher") != "ready":
		return _fail("a marker when the request can be met")
	var gold := hero.gold
	if not life.fulfil("fisher") or hero.gold != gold + 40 or not life.request_of("fisher").is_empty():
		return _fail("the request met and paid, one a day")
	game.day_night.day += 1
	if life.request_of("fisher").is_empty():
		return _fail("a new request the next day")
	# Saved.
	var snapshot := game.make_save_snapshot()
	life.requests_done = 0
	if not game.restore_save_snapshot(snapshot) or game.settlement_life.requests_done != 1:
		return _fail("survives a save")
	print("SETTLEMENT LIFE OK")
	quit()
