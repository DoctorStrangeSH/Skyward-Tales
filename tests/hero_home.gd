extends SceneTree

## Stage 21, step 10: the heroine's house from inside — bed, hearth,
## wardrobe, trophies of deeds; tools are not for sale.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("HERO HOME FAILED: " + reason)
	quit(1)

func _labels(game: SkywardGame) -> String:
	var text := ""
	for node in game.get_children():
		if node is TowerObject and not node.is_queued_for_deletion():
			text += node.label + "|"
	return text

func _hearths(game: SkywardGame) -> int:
	var count := 0
	for node in game.get_children():
		if node is TowerObject and not node.is_queued_for_deletion() and node.sheet == "lodge_hearth":
			count += 1
	return count

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var home := game.home

	# The door of the built house leads inside.
	game.settlement.buildings["home"] = 1
	game.refresh_settlement()
	await process_frame
	game.buildings.use_door("home")
	await process_frame
	await process_frame
	if game.current_region != HeroHome.REGION or not HeroHome.ROOM.has_point(hero.global_position):
		return _fail("the door leads into the room")
	var labels := _labels(game)
	for word in ["лечь спать", "гардероб", "выйти"]:
		if not labels.contains(word):
			return _fail("the room has: " + word)
	if _hearths(game) != 0 or not home.trophies().is_empty():
		return _fail("a plain room at first")
	# Sleep in the bed.
	hero.health = 3
	var day := game.day_night.day
	game.day_night.time = 0.6
	for node in game.get_children():
		if node is TowerObject and node.label.contains("лечь спать"):
			node.interact()
	if hero.health != hero.max_health or game.day_night.day != day + 1:
		return _fail("the bed gives a night's sleep")
	# Wardrobe.
	var name := hero.hero_name
	var gender := hero.hero_gender
	home.change_look()
	if hero.hero_gender == gender or hero.hero_name != name:
		return _fail("the wardrobe changes the look, not the name")
	home.change_look()
	if hero.hero_gender != gender:
		return _fail("and back")
	# Out.
	home.leave()
	await process_frame
	await process_frame
	if game.current_region != HeroHome.VILLAGE or hero.global_position.distance_to(Vector2(190, 390)) > 30.0:
		return _fail("the way out leads to the porch")

	# Deeds leave keepsakes; level 2 lights the hearth.
	game.settlement.buildings["home"] = 2
	game.trials.best = 5
	game.cistern.times_cleared = 1
	game.adit.guardian_down = true
	game.scout.runs_won = 3
	home.enter()
	await process_frame
	await process_frame
	if home.trophies().size() != 4 or _hearths(game) != 1:
		return _fail("four keepsakes and a hearth: %d" % home.trophies().size())
	labels = _labels(game)
	if not labels.contains("Знамя башни") or not labels.contains("Аметист жеоды") or labels.contains("Мишень"):
		return _fail("keepsakes stand in the room: " + labels)
	for node in game.get_children():
		if node is TowerObject and (not HeroHome.ROOM.grow(40.0).has_point(node.global_position)):
			return _fail("everything is inside the house")

	# Tools are not sold.
	hero.add_item("copper_pickaxe", 1)
	hero.add_item("copper_ore", 2)
	if game.merchant_shop.sellable_count(hero, "copper_pickaxe") != 0 or game.merchant_shop.sellable_count(hero, "copper_ore") != 2:
		return _fail("tools are not for sale")
	print("HERO HOME OK")
	quit(0)
