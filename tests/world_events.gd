extends SceneTree

## Random world events: starfall drops star fragments, an elite appears,
## the golden imp flees and pays out when caught, the tailwind speeds up.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("WORLD EVENTS TEST FAILED: " + reason)
	quit(1)

func _count(game: SkywardGame, test: Callable) -> int:
	var n := 0
	for node in game.get_children():
		if test.call(node):
			n += 1
	return n

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var events := game.events
	events.enabled = false
	events.rng.seed = 4
	var hero := game.player
	hero.global_position = Vector2(1000, 760)
	if not events.can_happen():
		return _fail("events can happen outdoors")

	events.start("starfall")
	for i in 240:
		await process_frame
	var stars := _count(game, func(n: Node) -> bool: return n is WorldLoot and n.item_id == "star_fragment")
	var picked := int(hero.inventory.get("star_fragment", 0))
	if stars + picked < 3:
		return _fail("a starfall drops at least three fragments (%d + %d)" % [stars, picked])

	var elites_before := _count(game, func(n: Node) -> bool: return n is SlimeEnemy and not n.elite_id.is_empty())
	if not events.start("elite") or _count(game, func(n: Node) -> bool: return n is SlimeEnemy and not n.elite_id.is_empty()) != elites_before + 1:
		return _fail("an elite appears")

	events.start("thief")
	var imp: LootImp = null
	for node in game.get_children():
		if node is LootImp:
			imp = node
	if imp == null:
		return _fail("the golden imp appears")
	var start := imp.global_position
	hero.global_position = start + Vector2(-60, 0)
	for i in 30:
		await process_frame
	if imp.global_position.x <= start.x:
		return _fail("the imp runs away from the hero")
	var gold_piles := _count(game, func(n: Node) -> bool: return n is WorldLoot and n.item_id == "gold")
	imp.take_damage(9999)
	await process_frame
	if _count(game, func(n: Node) -> bool: return n is WorldLoot and n.item_id == "gold") < gold_piles + 3:
		return _fail("a caught imp bursts into coins")

	var speed := hero.get_move_speed()
	events.start("tailwind")
	if hero.get_move_speed() <= speed:
		return _fail("the tailwind speeds the hero up")

	game._set_region("crystal_caves", Vector2(400, 400), false)
	await process_frame
	if events.can_happen():
		return _fail("no events underground")
	print("WORLD EVENTS OK: starfall, elite, golden imp, tailwind, none underground")
	quit(0)
