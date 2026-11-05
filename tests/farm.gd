extends SceneTree

## The village garden: built and upgraded at the settlement board, seeds
## from Bran, planting, watering, growth in game time, harvest, cooking
## bread and pie, level 3 extras, saving.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("FARM TEST FAILED: " + reason)
	quit(1)

func _beds(game: SkywardGame) -> Array:
	return game.get_children().filter(func(n: Node) -> bool: return n is FarmBed and not n.is_queued_for_deletion())

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	var hero := game.player
	var farm := game.farm
	if farm.level() != 0 or not _beds(game).is_empty():
		return _fail("no garden at the start")

	# Build it at the board.
	hero.gold = 2000
	hero.add_item("wood", 30)
	hero.add_item("stone", 20)
	hero.add_item("iron_ore", 5)
	game.settlement.open_board()
	var offered := game.hud.dialogue_choices_container.get_children().any(func(b: Node) -> bool: return b is Button and (b as Button).text.contains("Огород"))
	if not offered:
		return _fail("the board offers a garden")
	game.dialogues.handle_choice("settle_upgrade:farm")
	await process_frame
	if farm.level() != 1 or _beds(game).size() != 3 or hero.gold != 1920:
		return _fail("garden level 1: three beds")

	# Seeds from Bran.
	game.dialogues.on_merchant()
	var result: Dictionary = game.merchant_shop.purchase(hero, "seed_wheat", 0)
	game.hud.close_dialogue()
	if not bool(result.get("success", false)) or int(hero.inventory.get("seed_wheat", 0)) != 1:
		return _fail("Bran sells seeds")
	hero.add_item("seed_wheat", 3)
	hero.add_item("seed_sunberry", 2)

	# Plant, water, grow, harvest.
	var bed: FarmBed = _beds(game)[0]
	if game._interaction_prompt(bed) != "E — посадить":
		return _fail("empty bed prompt")
	bed.interact()
	game.dialogues.handle_choice("farm_plant:0:seed_wheat")
	if farm.growth(0) != 0.0 or int(hero.inventory.get("seed_wheat", 0)) != 3:
		return _fail("planted")
	if not game._interaction_prompt(bed).begins_with("E — полить"):
		return _fail("water prompt")
	bed.interact()
	if not bool(farm.beds[0]["watered"]) or not is_equal_approx(farm.growth_days(0), 0.35 * 0.5):
		return _fail("watering halves growth time")
	game.day_night.time += 0.1
	if farm.ripe(0) or farm.growth(0) <= 0.4:
		return _fail("growing in game time (%.2f)" % farm.growth(0))
	game.day_night.time += 0.1
	if not farm.ripe(0) or game._interaction_prompt(bed) != "E — собрать урожай":
		return _fail("ripe")
	bed.interact()
	var wheat := int(hero.inventory.get("wheat", 0))
	if wheat < 4 or farm.beds.has(0) or game.achievements.progress("farmer_10") != 1:
		return _fail("harvest wheat (%d)" % wheat)

	# Cook bread at the kitchen.
	var cooked: Dictionary = game.crafting_service.craft(hero, "cook_bread")
	if not bool(cooked.get("success", false)) or int(hero.inventory.get("bread", 0)) != 1:
		return _fail("bake bread: %s" % [cooked])

	# Level 2 and 3.
	game.settlement.upgrade("farm")
	await process_frame
	if farm.level() != 2 or _beds(game).size() != 6:
		return _fail("level 2: six beds")
	game.settlement.upgrade("farm")
	await process_frame
	if farm.level() != 3:
		return _fail("level 3")
	farm.plant(5, "seed_sunberry")
	if not is_equal_approx(farm.growth_days(5), 0.5 * 0.5 * 0.5) or not game._interaction_prompt(_beds(game)[5]).begins_with("Растёт"):
		return _fail("level 3 waters itself and grows faster")
	game.day_night.time += 0.13
	var berries := int(hero.inventory.get("sunberry", 0))
	farm.harvest(5)
	if int(hero.inventory.get("sunberry", 0)) < berries + 3:
		return _fail("level 3 gives one more crop")
	if not game.settlement.next_level("farm").is_empty():
		return _fail("level 3 is the top")

	# Saved.
	farm.plant(2, "seed_wheat")
	var snap := farm.make_snapshot()
	var settle := game.settlement.make_snapshot()
	farm.beds.clear()
	game.settlement.buildings.clear()
	farm.restore_snapshot(snap)
	game.settlement.restore_snapshot(settle)
	if not farm.beds.has(2) or farm.level() != 3:
		return _fail("garden and beds are saved")
	print("FARM OK: build, seeds, plant, water, grow, harvest, bread, levels, save")
	quit(0)
