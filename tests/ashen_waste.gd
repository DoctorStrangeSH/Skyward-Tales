extends SceneTree

## Ashen Waste: reachable by the bridge from the Stone Pass, new enemies and
## boss, the hermit's quest chain, lava fishing and weather.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("ASHEN WASTE TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game._set_region("stone_pass", Vector2(1480, 520), false)
	await process_frame
	var bridge: RegionGate = null
	for node in game.get_children():
		if node is RegionGate and node.target_region == "ashen_waste":
			bridge = node
	if bridge == null or bridge.kind != "bridge_h":
		return _fail("the Stone Pass has a bridge to the Ashen Waste")
	game._set_region("ashen_waste", bridge.arrival_position, false)
	await process_frame
	var kinds := {}
	var hermit := false
	var fishing := 0
	for node in game.get_children():
		if node is SlimeEnemy:
			kinds[SkywardGame.enemy_kind(node)] = true
		if node is WorldNpc and node.npc_id == "ash_hermit":
			hermit = true
		if node is GatherNode and node.kind == "fish":
			fishing += 1
	var lord: SlimeEnemy = game.spawn_enemy("ash_lord", Vector2(1250, 200))
	if lord == null or SkywardGame.enemy_kind(lord) != "ash_lord" or not lord.max_health > 400:
		return _fail("the Ash Lord spawns as a boss")
	kinds["ash_lord"] = true
	for kind in ["ember_hound", "magma_golem", "ash_cultist", "ash_lord"]:
		if not kinds.has(kind):
			return _fail("the waste has %s (found %s)" % [kind, str(kinds.keys())])
	if not hermit or fishing < 2:
		return _fail("Ignat's camp and lava fishing spots exist")
	if game.world.get_node_or_null("WeatherEmbers") == null:
		return _fail("embers drift over the waste")
	if not game.givers.has_giver("ash_hermit") or game.quests.definitions.get("ash_lord", {}).get("kill_kind", "") != "ash_lord":
		return _fail("the hermit gives the quest chain")
	var drops := {}
	for i in 40:
		for item in game.roll_drops("magma_golem", Vector2(200, 200)):
			drops[item] = true
	if not drops.has("obsidian_shard"):
		return _fail("magma golems drop obsidian")
	if not game.player.get_item_definition("obsidian_blade").get("slot", "") == "blade":
		return _fail("the obsidian blade exists")
	print("ASHEN WASTE OK: bridge, enemies, boss, hermit, fishing, weather, quests, drops")
	quit(0)
