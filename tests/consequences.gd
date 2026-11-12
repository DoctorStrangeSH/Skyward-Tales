extends SceneTree

## Этап 23: decisions in errands come back later, once, and survive a save.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CONSEQUENCES FAILED: " + reason)
	quit(1)

func _done(game: SkywardGame, id: String, choice: String = "") -> void:
	game.quests.states[id]["started"] = true
	game.quests.states[id]["completed"] = true
	if not choice.is_empty():
		game.quests.states[id]["choice"] = choice

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var c := game.consequences
	if c.entries.size() < 6:
		return _fail("consequences are loaded")
	for entry in c.entries:
		if not game.quests.definitions.has(str(entry["quest"])) or not game.quests.definitions.has(str(entry["after"])):
			return _fail("real quests in %s" % str(entry["id"]))
		if not (game.quests.definitions[str(entry["quest"])].get("choices", {}) as Dictionary).has(str(entry["choice"])):
			return _fail("a real choice in %s" % str(entry["id"]))
		for item in entry.get("items", {}):
			if hero.get_item_definition(str(item)).is_empty():
				return _fail("a real item %s" % str(item))
	_done(game, "moonleaf_gathering", "village")
	_done(game, "toren_wolf_hunt", "supplies")
	if not c.due().is_empty():
		return _fail("nothing before the chapters")
	_done(game, "main_guardian")
	c.check()
	if int(hero.inventory.get("reaches_charm", 0)) != 1:
		return _fail("the village remembers: the charm")
	c.check()
	if int(hero.inventory.get("reaches_charm", 0)) != 1:
		return _fail("once only")
	var snapshot := game.make_save_snapshot()
	c.delivered.clear()
	if not game.restore_save_snapshot(snapshot) or not game.consequences.delivered.has("village_gift"):
		return _fail("delivered ones survive a save")
	_done(game, "main_echo")
	game.consequences.check()
	if not game.player.knows("keen_eye"):
		return _fail("Toren teaches the keen eye")
	print("CONSEQUENCES OK")
	quit()
