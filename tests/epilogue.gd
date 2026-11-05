extends SceneTree

## After the finale: the herald appears, the ending's blessing works, six
## rifts can be closed (echoes pour out, the last one seals the rift), the
## Shadow of the Pattern waits in the Heart of the Sky, the reward follows
## the ending, and everything is saved.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("EPILOGUE TEST FAILED: " + reason)
	quit(1)

func _find(game: SkywardGame, check: Callable) -> Node:
	for node in game.get_children():
		if not node.is_queued_for_deletion() and check.call(node):
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var herald_check := func(n: Node) -> bool: return n is WorldNpc and n.npc_id == "herald"
	if _find(game, herald_check) != null:
		return _fail("no herald before the finale")
	if game.epilogue.ending() != "" or not is_equal_approx(game.epilogue.gold_mult(), 1.0):
		return _fail("no blessing before the finale")

	# The finale: lower the islands.
	game.quests.states["main_heart"]["completed"] = true
	game.director.set_flag("ending_lower")
	game._set_region("greenreach", Vector2(600, 600), false)
	await process_frame
	var herald: WorldNpc = _find(game, herald_check)
	if herald == null:
		return _fail("the herald waits in Greenreach after the finale")
	if not is_equal_approx(game.epilogue.gold_mult(), 1.15) or not is_equal_approx(game.epilogue.xp_mult(), 1.0):
		return _fail("lowered islands: +15% gold")
	if game.givers.marker_for("herald") != "quest":
		return _fail("the herald offers the rifts")
	game.givers.handle_choice("giver_accept:post_rifts")
	if not game.quests.is_active("post_rifts"):
		return _fail("rift quest taken")

	# Close every rift.
	var regions: Array = game.epilogue.rifts.keys()
	if regions.size() != 6:
		return _fail("six rifts")
	game.player.max_health = 99999
	game.player.health = 99999
	for region_id in regions:
		game._set_region(str(region_id), Vector2(200, 200), false)
		await process_frame
		var rift: PatternRift = _find(game, func(n: Node) -> bool: return n is PatternRift)
		if rift == null:
			return _fail("rift in " + str(region_id))
		if not game.minimap_markers().is_empty() and game.epilogue.minimap_marker().is_empty():
			return _fail("rift on the minimap")
		if game._interaction_prompt(rift) != "E — закрыть разлом":
			return _fail("rift prompt")
		rift.interact()
		var echoes: Array = []
		for node in game.get_children():
			if node is SlimeEnemy and node.has_meta("rift_echo"):
				echoes.append(node)
		if echoes.size() != Epilogue.ECHO_COUNT:
			return _fail("echoes pour out in %s: %d" % [region_id, echoes.size()])
		if not rift.awake:
			return _fail("rift is awake during the wave")
		for echo in echoes:
			(echo as SlimeEnemy).take_damage(999999)
		await process_frame
		if not game.epilogue.closed.has(region_id):
			return _fail("last echo seals the rift in " + str(region_id))
		if _find(game, func(n: Node) -> bool: return n is WorldLoot and n.item_id == "pattern_shard") == null:
			return _fail("rift drops pattern shards")
	if not game.quests.is_ready_to_complete("post_rifts"):
		return _fail("six rifts complete the quest")
	if int(game.achievements.progress("rift_closer")) != 6:
		return _fail("rift achievement counts")
	game._set_region("salt_coast", Vector2(400, 600), false)
	await process_frame
	if _find(game, func(n: Node) -> bool: return n is PatternRift) != null:
		return _fail("a closed rift stays closed")

	# Turn in, take the Shadow.
	game._set_region("greenreach", Vector2(600, 600), false)
	await process_frame
	game.givers.talk("herald")
	if not game.quests.is_completed("post_rifts"):
		return _fail("rifts turned in")
	game.givers.handle_choice("giver_accept:post_shadow")
	game._set_region("sky_heart", Vector2(640, 700), false)
	await process_frame
	var shade: SlimeEnemy = _find(game, func(n: Node) -> bool: return n is PatternShade)
	if shade == null:
		return _fail("the Shadow waits in the Heart of the Sky")
	if SkywardGame.enemy_kind(shade) != "pattern_shade" or shade.max_health < 2400:
		return _fail("the Shadow is a superboss")
	shade.take_damage(999999)
	await process_frame
	if not game.quests.is_ready_to_complete("post_shadow"):
		return _fail("the Shadow's defeat completes the quest")
	game._set_region("greenreach", Vector2(600, 600), false)
	await process_frame
	game.givers.talk("herald")
	if int(game.player.inventory.get("earth_star", 0)) != 1 or int(game.player.inventory.get("sky_thread", 0)) != 0:
		return _fail("reward follows the ending (lowered → Звезда земли)")

	# Saved.
	game.epilogue.closed.clear()
	game.epilogue.restore_snapshot({"closed": {"salt_coast": true}})
	if not game.epilogue.closed.has("salt_coast"):
		return _fail("rifts restore from a save")
	print("EPILOGUE OK: herald, blessing, six rifts, Shadow of the Pattern, ending reward, save")
	quit(0)
