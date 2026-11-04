extends SceneTree

## Forge Depths: stairs down from the Ashen Waste, fire vents that burn,
## a key door, a seal that opens after three levers, the Titan boss.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("FORGE DEPTHS TEST FAILED: " + reason)
	quit(1)

func _find(game: SkywardGame, test: Callable) -> Array:
	var found: Array = []
	for node in game.get_children():
		if test.call(node):
			found.append(node)
	return found

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	game._set_region("ashen_waste", Vector2(1500, 900), false)
	await process_frame
	var stairs := _find(game, func(n: Node) -> bool: return n is RegionGate and n.target_region == "forge_depths")
	if stairs.is_empty() or stairs[0].kind != "stairs_down":
		return _fail("stairs lead down from the Ashen Waste")
	game._set_region("forge_depths", Vector2(240, 860), false)
	await process_frame
	var up := _find(game, func(n: Node) -> bool: return n is RegionGate)
	if up.is_empty() or up[0].kind != "stairs_up":
		return _fail("stairs lead back up")
	var vents := _find(game, func(n: Node) -> bool: return n is FlameVent)
	var levers := _find(game, func(n: Node) -> bool: return n is DungeonLever)
	var doors := _find(game, func(n: Node) -> bool: return n is DungeonDoor)
	if vents.size() < 8 or levers.size() != 3 or doors.size() != 2:
		return _fail("vents %d, levers %d, doors %d" % [vents.size(), levers.size(), doors.size()])
	# A vent in eruption burns the hero standing on it.
	var vent: FlameVent = vents[0]
	hero.global_position = vent.global_position
	var health := hero.health
	vent.clock = FlameVent.IDLE_TIME + FlameVent.WARN_TIME + 0.05
	for i in 6:
		await process_frame
	if not vent.is_dangerous() or hero.health >= health:
		return _fail("an erupting vent burns")
	hero.health = hero.max_health
	# The seal ignores the hero until three levers are pulled.
	var seal: DungeonDoor = null
	for door in doors:
		if not door.levers.is_empty():
			seal = door
	if seal == null:
		return _fail("the boss hall has a lever seal")
	game._on_door_used(seal)
	if seal.is_open:
		return _fail("the seal stays shut without levers")
	for i in 3:
		game._on_lever_used(levers[i])
		if i < 2 and seal.is_open:
			return _fail("the seal needs all three levers")
	if not seal.is_open or not bool(game.opened_doors.get("forge_seal", false)):
		return _fail("three levers open the seal")
	var data := GameSaveState.capture(game)
	game.opened_doors.clear()
	GameSaveState.apply(game, data)
	if not bool(game.opened_doors.get("forge_lever_2", false)):
		return _fail("pulled levers are saved")
	var titan: SlimeEnemy = game.spawn_enemy("forge_titan", Vector2(1088, 790))
	if titan == null or SkywardGame.enemy_kind(titan) != "forge_titan" or titan.max_health < 700:
		return _fail("the Titan of the Crucible spawns")
	if not game.quests.definitions.get("forge_titan", {}).get("requires_quest", "") == "ash_lord":
		return _fail("Ignat's fourth quest follows the Ash Lord")
	print("FORGE DEPTHS OK: stairs, vents, levers, seal, save, titan, quest")
	quit(0)
