extends SceneTree

## Stage 21, step 4: the seasons, the greenhouse, the watermill, carrots.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("HOMESTEAD FAILED: " + reason)
	quit(1)

func _trees(game: SkywardGame, word: String) -> int:
	var count := 0
	for node in game.world.get_children():
		if node is Sprite2D and node.has_meta("season_tree") and (word.is_empty() or (node as Sprite2D).texture.resource_path.contains(word)):
			count += 1
	return count

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var farm := game.farm
	var seasons := game.seasons

	# The calendar.
	if Seasons.season_of(0) != "summer" or Seasons.season_of(4) != "autumn" or Seasons.season_of(8) != "winter" or Seasons.season_of(12) != "spring" or Seasons.season_of(16) != "summer":
		return _fail("four seasons of four days")
	await process_frame
	var tree_count := _trees(game, "")
	if tree_count == 0:
		return _fail("the authored forest is present")

	if not seasons.here() or _trees(game, "season_") != 0:
		return _fail("summer keeps the land's own trees")
	game.day_night.day = 4
	await process_frame
	await process_frame
	if _trees(game, "season_autumn") < int(tree_count * 0.8):
		return _fail("autumn turns the trees: %d" % _trees(game, "season_autumn"))
	for i in 40:
		await process_frame
	if game.world.get_node_or_null("SeasonLayer") == null or game.hud.minimap.season_label != "осень":
		return _fail("autumn veil and the label on the map")
	game.day_night.day = 8
	await process_frame
	await process_frame
	if _trees(game, "season_winter") != tree_count or _trees(game, "season_autumn") != 0:
		return _fail("winter trees")

	# Garden in winter: no planting outdoors; the greenhouse works.
	game.settlement.buildings = {"farm": 1}
	farm.refresh()
	hero.add_item("seed_carrot", 4)
	hero.add_item("seed_wheat", 4)
	if farm.plant(0, "seed_carrot"):
		return _fail("frozen soil takes no seeds")
	if farm.usable(Farm.TRAY_FIRST):
		return _fail("no trays without a greenhouse")
	game.settlement.buildings["greenhouse"] = 1
	game.settlement.buildings["mill"] = 1
	game.refresh_settlement()
	await process_frame
	var wheels := 0
	var doors := 0
	for node in game.get_children():
		if node is MillWheel and not node.is_queued_for_deletion():
			wheels += 1
		if node is SettlementObject and node.kind == "door" and not node.is_queued_for_deletion() and node.label.contains("теплица"):
			doors += 1
	if wheels != 1 or doors != 1:
		return _fail("the mill wheel turns, the greenhouse has a door: %d %d" % [wheels, doors])
	if farm.tray_count() != 3 or not farm.plant(Farm.TRAY_FIRST, "seed_carrot"):
		return _fail("a tray takes seeds in winter")
	farm.open_greenhouse()
	var text := ""
	for button in game.hud.dialogue_choices_container.get_children():
		text += (button as Button).text + "\n"
	if not text.contains("Лоток 1: Морковь растёт") or not text.contains("Лоток 3: пусто"):
		return _fail("the greenhouse lists its trays:\n" + text)
	game._on_dialogue_choice_selected("farm_close")
	farm.beds[Farm.TRAY_FIRST]["planted"] = farm._now() - 1.0
	if not farm.ripe(Farm.TRAY_FIRST) or not farm.harvest(Farm.TRAY_FIRST) or int(hero.inventory.get("carrot", 0)) < 3:
		return _fail("carrots ripen under glass")

	# Spring is faster, autumn is richer.
	game.day_night.day = 12
	await process_frame
	if not farm.plant(0, "seed_wheat"):
		return _fail("spring planting")
	var spring_days := farm.growth_days(0)
	game.day_night.day = 16
	if spring_days >= farm.growth_days(0):
		return _fail("spring grows faster than summer")
	game.day_night.day = 4
	farm.beds[0]["planted"] = farm._now() - 2.0
	farm.rng.seed = 1
	var before := int(hero.inventory.get("wheat", 0))
	farm.harvest(0)
	if int(hero.inventory.get("wheat", 0)) - before < 5:
		return _fail("autumn harvest +1")

	# The mill and the kitchen.
	hero.add_item("wheat", 4)
	var wheat := int(hero.inventory.get("wheat", 0))
	game.buildings.use_door("mill")
	if not game.crafting.is_open() or not game.crafting.recipes_for("mill").has("mill_flour"):
		return _fail("the mill grinds")
	game.crafting.craft_many("mill_flour", 1)
	if int(hero.inventory.get("flour", 0)) != 3 or int(hero.inventory.get("wheat", 0)) != wheat - 2:
		return _fail("2 wheat → 3 flour")
	game.crafting.close()
	if not game.crafting.recipes_for("kitchen").has("cook_carrot_pie"):
		return _fail("the kitchen bakes carrot pies")
	hero.add_item("carrot_pie", 1)
	var crit := hero.get_crit_chance()
	hero.use_item("carrot_pie")
	if hero.get_crit_chance() <= crit:
		return _fail("the pie sharpens the eye")

	# Other lands keep their own climate.
	game.day_night.day = 8
	if Seasons.tree_file("winter", "day", 0, Vector2.ZERO).is_empty() or RegionCatalog.style("salt_coast") in Seasons.SEASONAL_STYLES:
		return _fail("the coast has no winter")
	print("HOMESTEAD OK")
	quit(0)
