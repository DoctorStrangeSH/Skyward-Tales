extends SceneTree

## Stage 21, step 8: the Foresters' Lodge — felled trees that grow back,
## saplings, ranks, the room with Orvin, the bench, the hearth and the bed.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("FOREST GUILD FAILED: " + reason)
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
	var guild := game.forestry
	guild.rng.seed = 3

	# Trees for felling are trees.
	var trees: Array = []
	for node in game.get_children():
		if node is GatherNode and node.kind == "wood":
			trees.append(node)
	if trees.size() < 8:
		return _fail("a grove by the lodge: %d trees" % trees.size())
	var tree: GatherNode = trees[0]
	if not tree.staged_art().begins_with("props/tree_") or not ResourceLoader.exists("res://assets/world_hd/%s.png" % tree.staged_art()):
		return _fail("a tree has its art: " + tree.staged_art())
	var wood := int(hero.inventory.get("wood", 0))
	if not game.crafting.gather(tree):
		return _fail("the tree is felled")
	if tree.stage != "cut" or tree.modulate.a < 1.0 or guild.points != 1 or guild.felled != 1:
		return _fail("a stump is left, a point is earned")
	var first := int(hero.inventory.get("wood", 0)) - wood
	if first < 2:
		return _fail("logs from the tree")

	# A sapling on the stump halves the wait.
	hero.inventory.erase("sapling")
	game.crafting.gather(tree)
	if guild.planted.has(tree.key):
		return _fail("no planting without a sapling")
	hero.add_item("sapling", 1)
	var left := float(game.crafting.cooldowns[tree.key]) - game.crafting.play_time
	game.crafting.gather(tree)
	var after := float(game.crafting.cooldowns[tree.key]) - game.crafting.play_time
	if not guild.planted.has(tree.key) or tree.stage != "young" or after > left * 0.55 or guild.points != 3:
		return _fail("the sapling is planted: %.0f → %.0f" % [left, after])
	if int(hero.inventory.get("sapling", 0)) != 0:
		return _fail("the sapling is used")
	hero.add_item("sapling", 1)
	game.crafting.gather(tree)
	if int(hero.inventory.get("sapling", 0)) != 1:
		return _fail("one sapling per stump")
	# It grows back.
	game.crafting.play_time += 1000.0
	game.crafting.refresh_nodes()
	if not tree.available or tree.stage != "ready":
		return _fail("the tree grows back")

	# Ranks.
	guild.points = 9
	game.crafting.gather(tree)
	if guild.rank() != 1 or guild.rank_name() != "Лесоруб":
		return _fail("rank Лесоруб at 10 points")
	wood = int(hero.inventory.get("wood", 0))
	game.crafting.gather(trees[1])
	if int(hero.inventory.get("wood", 0)) - wood < 3:
		return _fail("a woodcutter gets one more log")
	guild.points = 60
	if guild.rank() != 3 or guild.regrow_factor(tree) != 0.5 or guild.regrow_factor(null if false else trees[2]) != 0.5:
		return _fail("the keeper's trees grow twice as fast")
	# An ore vein shows as worked out, not faded.
	var vein := GatherNode.new()
	vein.kind = "iron"
	vein.key = "test:0"
	game.add_child(vein)
	vein.set_ready(false)
	if vein.staged_art() != "props/vein_cut" or vein.modulate.a < 1.0:
		return _fail("a worked-out vein")
	vein.queue_free()

	# The cottage and the room.
	if not _labels(game).contains("войти в дом лесничих"):
		return _fail("the cottage stands in the woods")
	guild.enter()
	await process_frame
	await process_frame
	if game.current_region != ForestGuild.LODGE:
		return _fail("the hero enters the lodge")
	var labels := _labels(game)
	for word in ["верстак", "очага", "вздремнуть", "выйти", "сундук гильдии"]:
		if not labels.contains(word):
			return _fail("the room has: " + word)
	var orvin: WorldNpc = null
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "forester":
			orvin = node
	if orvin == null:
		return _fail("Orvin is at home")
	if not ForestGuild.ROOM.has_point(orvin.global_position) or not ForestGuild.ROOM.has_point(hero.global_position):
		return _fail("everyone stands in the room")
	orvin.interact()
	await process_frame
	var text := ""
	for button in game.hud.dialogue_choices_container.get_children():
		text += (button as Button).text + "\n"
	if not text.contains("саженцы"):
		return _fail("Orvin offers saplings:\n" + text)
	var saplings := int(hero.inventory.get("sapling", 0))
	game._on_dialogue_choice_selected("forest_saplings")
	game._on_dialogue_choice_selected("forest_saplings")
	if int(hero.inventory.get("sapling", 0)) != saplings + 3:
		return _fail("three saplings a day")
	game._on_dialogue_choice_selected("forest_close")
	# Bench, bed, hearth, chest.
	if not game.crafting.recipes_for("carpentry").has("carp_planks"):
		return _fail("the bench makes planks")
	hero.health = 5
	guild.nap()
	if hero.health != hero.max_health:
		return _fail("a nap restores health")
	hero.health = 5
	guild.nap()
	if hero.health != 5:
		return _fail("one nap a day")
	guild.warm_up()
	if hero.buff_value("regen") <= 0.0:
		return _fail("the hearth warms")
	for node in game.get_children():
		if node is TowerObject and node.label.contains("сундук"):
			node.interact()
	if not guild.gift_taken or int(hero.inventory.get("sapling", 0)) != saplings + 8:
		return _fail("the guild chest holds a gift")
	guild.leave()
	await process_frame
	await process_frame
	if game.current_region != ForestGuild.HOME or hero.global_position.distance_to(ForestGuild.COTTAGE) > 60.0:
		return _fail("the door leads back")

	var snapshot := guild.make_snapshot()
	guild.restore_snapshot({})
	guild.restore_snapshot(snapshot)
	if guild.points != 60 or not guild.gift_taken:
		return _fail("the guild is saved")
	print("FOREST GUILD OK")
	quit(0)
