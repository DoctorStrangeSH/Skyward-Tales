extends SceneTree

## Region layouts come from data/regions.json, players see item names instead
## of internal ids, and enemies drop loot where they died.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("REGION LAYOUT TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _count(game: Node, type_check: Callable) -> int:
	var total := 0
	for node in game.get_children():
		if not node.is_queued_for_deletion() and type_check.call(node):
			total += 1
	return total

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Greenreach layout from data.
	if not _verify(_count(game, func(n: Node) -> bool: return n is WorldNpc) == 6, "greenreach has six NPCs (with Lira the alchemist)"):
		return
	if not _verify(_count(game, func(n: Node) -> bool: return n is TreasureChest) == 7, "greenreach has seven chests"):
		return
	if not _verify(_count(game, func(n: Node) -> bool: return n is SlimeEnemy) == 3, "greenreach has three slimes"):
		return
	if not _verify(game.elder != null and game.elder.display_name == "Старейшина Элиан", "elder reference is set"):
		return

	# Grove layout from data; boss only after the warden's quest.
	game.quests.states["moonleaf_gathering"]["completed"] = true
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	await process_frame
	if not _verify(_count(game, func(n: Node) -> bool: return n is ForestWolf) == 2, "grove has two wolves"):
		return
	if not _verify(_count(game, func(n: Node) -> bool: return n is GroveGuardian) == 0, "guardian is hidden before grove quest"):
		return
	game.quests.states["grove_spirits"]["completed"] = true
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	await process_frame
	if not _verify(_count(game, func(n: Node) -> bool: return n is GroveGuardian) == 1, "guardian appears after grove quest"):
		return
	game.spawn_enemy("guardian", Vector2(10, 10))
	if not _verify(_count(game, func(n: Node) -> bool: return n is GroveGuardian) == 1, "guardian is never duplicated"):
		return

	# Secrets are revealed from data positions.
	game.reveal_secret("greenreach", "elder_hidden_storehouse")
	var marker: Dictionary = game.discovered_landmarks["greenreach"]["elder_hidden_storehouse"]
	if not _verify(marker["kind"] == "secret" and Vector2(marker["position"][0], marker["position"][1]) == Vector2(1380, 340), "secret marker uses data position"):
		return

	# Readable item names in messages.
	game._on_chest_opened("test_chest", 10, "health_potion", 2)
	if not _verify(game.hud.message_label.text.contains("Зелье здоровья") and not game.hud.message_label.text.contains("health_potion"), "chest message uses item name"):
		return
	game._on_loot_collected("wolf_pelt", 1)
	if not _verify(game.hud.message_label.text == "Получено: Волчья шкура ×1", "loot message uses item name"):
		return
	game._on_inventory_use("iron_ore")
	if not _verify(game.hud.message_label.text.begins_with("Железная руда — "), "materials show their description"):
		return

	# Slimes drop loot where they die, not at their spawn point.
	game._set_region("greenreach", Vector2(130, 210), false)
	await process_frame
	var slime: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and not node.is_queued_for_deletion():
			slime = node
			break
	if not _verify(slime != null, "slime exists"):
		return
	slime.global_position = Vector2(222, 333)
	slime.defeated.emit(5)
	var dropped_here := false
	for node in game.get_children():
		if node is WorldLoot and node.global_position == Vector2(222, 333):
			dropped_here = true
	if not _verify(dropped_here, "slime loot drops at death position"):
		return

	print("REGION LAYOUT OK: data-driven regions, boss gating, secrets, item names, loot position")
	quit(0)
