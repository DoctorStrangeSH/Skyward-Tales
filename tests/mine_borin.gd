extends SceneTree

## Borin's story and the Stone Pass mine: the quest overruns the mine, the
## Ore Leader frees it (miners, rich veins, star iron), tempering with
## obsidian, the Skyclaw blade, the upgraded forge and its shop; iron sells
## dear while the mine is lost.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("MINE TEST FAILED: " + reason)
	quit(1)

func _find(game: SkywardGame, check: Callable) -> Node:
	for node in game.get_children():
		if not node.is_queued_for_deletion() and check.call(node):
			return node
	return null

func _count(game: SkywardGame, check: Callable) -> int:
	var total := 0
	for node in game.get_children():
		if not node.is_queued_for_deletion() and check.call(node):
			total += 1
	return total

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	game.player.max_health = 99999
	game.player.health = 99999

	if game.borin.marker() != "":
		return _fail("Borin waits until the hero is seasoned")
	game.player.level = 7
	if game.dialogues.marker_for("blacksmith") != "quest":
		return _fail("Borin offers his dream")
	game.dialogues.on_blacksmith()
	game.dialogues.handle_choice("borin_accept:dream")
	if not game.quests.is_active("borin_dream") or not game.mine.overrun():
		return _fail("the quest sends the hero to an overrun mine")
	game.quest_nav.refresh()
	if not game.quest_nav.region_badges().get("stone_pass", {}).has("side"):
		return _fail("the mine is marked on the world map")

	# Iron is dear while the mine is lost.
	game.dialogues.on_merchant()
	if game.merchant_shop.get_sell_price("iron_ore", 0) != 10:
		return _fail("iron sells dear: %d" % game.merchant_shop.get_sell_price("iron_ore", 0))
	game.hud.close_dialogue()

	# The overrun mine.
	game._set_region("stone_pass", Vector2(1190, 760), false)
	await process_frame
	var leader: SlimeEnemy = _find(game, func(n: Node) -> bool: return n is OreGolem)
	if leader == null or SkywardGame.enemy_kind(leader) != "ore_golem":
		return _fail("the Ore Leader holds the mine")
	if _find(game, func(n: Node) -> bool: return n is WorldNpc and n.npc_id == "pass_miner") != null:
		return _fail("no miners while the mine is lost")
	if _find(game, func(n: Node) -> bool: return n is WorldCollectible and n.item_id == "meteor_iron") != null:
		return _fail("star iron is out of reach")
	var veins := _count(game, func(n: Node) -> bool: return n is GatherNode and n.kind == "iron")
	leader.take_damage(999999)
	await process_frame
	if game.mine.overrun() or not game.mine.cleared():
		return _fail("beating the leader frees the mine")
	var miner: WorldNpc = _find(game, func(n: Node) -> bool: return n is WorldNpc and n.npc_id == "pass_miner")
	if miner == null:
		return _fail("the miners come back")
	if _count(game, func(n: Node) -> bool: return n is GatherNode and n.kind == "iron") != veins + 2:
		return _fail("rich veins open at the mouth")
	var ore := int(game.player.inventory.get("iron_ore", 0))
	miner.interact()
	if int(game.player.inventory.get("iron_ore", 0)) != ore + 6:
		return _fail("the miner's gift")
	game.hud.close_dialogue()
	var meteor: WorldCollectible = _find(game, func(n: Node) -> bool: return n is WorldCollectible and n.item_id == "meteor_iron")
	if meteor == null:
		return _fail("star iron lies at the mouth")
	game.pickups.handle(meteor)
	if not game.quests.is_ready_to_complete("borin_dream"):
		return _fail("star iron found")
	if game.achievements.progress("mine_freed") != 1:
		return _fail("mine achievement")

	# Back to Borin: tempering.
	game._set_region("greenreach", Vector2(420, 760), false)
	await process_frame
	if game.dialogues.marker_for("blacksmith") != "ready":
		return _fail("Borin waits for the iron")
	game.dialogues.on_blacksmith()
	if not game.quests.is_completed("borin_dream"):
		return _fail("the dream quest completes")
	game.dialogues.handle_choice("borin_accept:temper")
	if not game.quests.is_active("borin_temper"):
		return _fail("tempering quest taken")
	game.player.add_item("obsidian_shard", 3)
	game._refresh_hud()
	if int(game.quests.states["borin_temper"]["progress"]) != 3 or game.borin.marker() != "ready":
		return _fail("shards count in the tracker")
	var sprites_before := game.world.get_child_count()
	game.dialogues.on_blacksmith()
	game.hud.close_dialogue()
	await process_frame
	if int(game.player.inventory.get("skyclaw_blade", 0)) != 1 or int(game.player.inventory.get("obsidian_shard", 0)) != 0:
		return _fail("the Skyclaw blade")
	if not game.director.has_flag("borin_forge_2") or game.world.get_child_count() <= sprites_before:
		return _fail("the forge grows (%d → %d)" % [sprites_before, game.world.get_child_count()])

	# The new shop.
	game.player.gold = 1000
	game.dialogues.on_blacksmith()
	game.dialogues.handle_choice("borin_buy:steel_sword")
	if int(game.player.inventory.get("steel_sword", 0)) != 1 or game.player.gold != 780:
		return _fail("Borin sells steel")
	game.hud.close_dialogue()
	print("MINE OK: overrun mine, leader, miners, veins, star iron, tempering, Skyclaw, new forge and shop")
	quit(0)
