extends SceneTree

## Stage 21, step 9: the Old Adit — copper, the minecart, cave-ins that need
## a pickaxe, tools that work from the bag, the geode and its Guardian.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("OLD ADIT FAILED: " + reason)
	quit(1)

func _labels(game: SkywardGame) -> String:
	var text := ""
	for node in game.get_children():
		if node is TowerObject and not node.is_queued_for_deletion():
			text += node.label + "|"
	return text

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var adit := game.adit

	if not _labels(game).contains("спуститься в штольню"):
		return _fail("the adit opens in the north of Greenreach")
	adit.enter()
	await process_frame
	await process_frame
	if game.current_region != OldAdit.REGION:
		return _fail("the hero goes down")
	# Veins.
	var copper: Array = []
	var amethysts := 0
	for node in game.get_children():
		if node is GatherNode and node.kind == "copper":
			copper.append(node)
		if node is GatherNode and node.kind == "amethyst":
			amethysts += 1
	if copper.size() != 6 or amethysts != 3:
		return _fail("six copper veins and three amethysts: %d %d" % [copper.size(), amethysts])
	game.crafting.gather(copper[0])
	var first := int(hero.inventory.get("copper_ore", 0))
	if first < 1 or copper[0].staged_art() != "props/vein_cut":
		return _fail("copper is mined")

	# The cart.
	var cart: OldAdit.Cart = null
	for node in game.get_children():
		if node is OldAdit.Cart:
			cart = node
	if cart == null or cart.global_position != OldAdit.CART_STOPS[0]:
		return _fail("the cart waits at the entry")
	cart.interact()
	if not cart.riding:
		return _fail("the ride starts")
	for i in 400:
		await process_frame
		if not cart.riding:
			break
	if cart.riding or cart.global_position != OldAdit.CART_STOPS[1] or hero.global_position.distance_to(OldAdit.CART_STOPS[1]) > 30.0:
		return _fail("the cart carries the hero to the copper hall")
	if not hero.is_physics_processing():
		return _fail("the hero walks again")

	# Cave-ins need a pickaxe.
	if not _labels(game).contains("разобрать завал"):
		return _fail("cave-ins block the branches")
	if adit.clear_rubble(0) or bool(adit.cleared[0]):
		return _fail("no pickaxe — no way")
	if not game.crafting.recipes_for("carpentry").has("carp_pickaxe"):
		return _fail("the bench makes a pickaxe")
	hero.add_item("copper_pickaxe", 1)
	if not adit.clear_rubble(0) or not adit.clear_rubble(1):
		return _fail("the pickaxe clears the rubble")
	await process_frame
	if _labels(game).contains("разобрать завал"):
		return _fail("the rubble is gone")
	# Tools from the bag.
	var before := int(hero.inventory.get("copper_ore", 0))
	game.crafting.gather(copper[1])
	if int(hero.inventory.get("copper_ore", 0)) - before < 2:
		return _fail("the pickaxe gives one more")
	if adit.tool_bonus(copper[2]) != 1:
		return _fail("pickaxe bonus")
	var tree := GatherNode.new()
	tree.kind = "wood"
	if adit.tool_bonus(tree) != 0:
		return _fail("no axe yet")
	hero.add_item("copper_axe", 1)
	if adit.tool_bonus(tree) != 1:
		return _fail("the axe gives one more log")
	tree.free()

	# The Guardian of the geode.
	var guardian: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("adit_guardian"):
			guardian = node
	if guardian == null:
		return _fail("the Guardian stands in the geode hall")
	game._strike(guardian, 999999, Vector2.RIGHT, 0.0)
	for i in 4:
		await process_frame
	var chest := false
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "adit_geode":
			chest = true
	if not adit.guardian_down or not chest or game.achievements.progress("adit_geode") != 1:
		return _fail("the geode chest appears")

	# Out and saved.
	adit.leave()
	await process_frame
	await process_frame
	if game.current_region != OldAdit.HOME:
		return _fail("the way out")
	var snapshot := adit.make_snapshot()
	adit.restore_snapshot({})
	if bool(adit.cleared[0]):
		return _fail("a fresh save has rubble")
	adit.restore_snapshot(snapshot)
	if not bool(adit.cleared[1]) or not adit.guardian_down:
		return _fail("the adit is saved")
	adit.enter()
	await process_frame
	await process_frame
	if _labels(game).contains("разобрать завал"):
		return _fail("cleared rubble stays cleared")
	print("OLD ADIT OK")
	quit(0)
