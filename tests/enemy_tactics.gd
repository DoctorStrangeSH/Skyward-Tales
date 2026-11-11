extends SceneTree

## Review item 4: enemies differ by behaviour, not only by numbers.
##  - the skeleton walks behind a shield and opens up after its own swing;
##  - the shaman wards an ally (two blows glance off);
##  - wolves of a pack close in from two sides;
##  - the crab waits buried and bursts out in an ambush.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("ENEMY TACTICS FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	var hero := game.player
	hero.global_position = Vector2(900, 900)
	game.crit_rng.seed = 1
	var crit_chance := hero.get_crit_chance()

	# --- The skeleton's shield.
	var bones: Skeleton = game.spawn_enemy("skeleton", hero.global_position + Vector2(20, 0))
	bones.set_physics_process(false)
	bones.max_health = 1000
	bones.health = 1000
	if not bones.guarding():
		return _fail("the skeleton walks with its shield up")
	game._strike(bones, 40, Vector2.RIGHT, 0.0)
	var blocked := 1000 - bones.health
	if blocked < 1 or blocked > 40 * Skeleton.GUARD * 2.1 + 1:
		return _fail("the shield takes most of a blade's blow: %d" % blocked)
	# A spell goes around the shield.
	bones.health = 1000
	bones.take_damage(40)
	if bones.health != 960:
		return _fail("spells go around the shield")
	# After its own swing it is open, and hurts more.
	bones.health = 1000
	bones.open_left = Skeleton.OPEN_TIME
	if bones.guarding():
		return _fail("after a swing the shield is down")
	game._strike(bones, 40, Vector2.RIGHT, 0.0)
	if 1000 - bones.health < 40 * Skeleton.OPEN_BONUS - 1:
		return _fail("an open skeleton takes the full blow and more: %d" % (1000 - bones.health))
	# Frost breaks the guard too.
	bones.open_left = 0.0
	bones.apply_slow(0.5, 2.0)
	if bones.guarding():
		return _fail("a frozen skeleton cannot hold the shield")
	bones.slow_time_left = 0.0
	# The swing itself opens it: let it attack the hero.
	bones.set_physics_process(true)
	bones.attack_cooldown = 0.0
	bones.global_position = hero.global_position + Vector2(10, 0)
	var opened := false
	for i in 90:
		await physics_frame
		if bones.open_left > 0.0:
			opened = true
			break
	if not opened:
		return _fail("the skeleton opens up after it swings")
	bones.free()
	hero.health = hero.max_health

	# --- The shaman's ward.
	var shaman: ForestShaman = game.spawn_enemy("shaman", hero.global_position + Vector2(120, 0))
	shaman.set_physics_process(false)
	if shaman.cast_ward():
		return _fail("no ally — no ward")
	var slime := game.spawn_enemy("slime", hero.global_position + Vector2(60, 0))
	slime.set_physics_process(false)
	slime.max_health = 500
	slime.health = 500
	if shaman.ward_target() != slime or not shaman.cast_ward() or slime.ward_hits != 2:
		return _fail("the shaman wards the nearest ally")
	if shaman.cast_ward():
		return _fail("a warded ally is not warded twice")
	game._strike(slime, 50, Vector2.RIGHT, 0.0)
	game._strike(slime, 50, Vector2.RIGHT, 0.0)
	if slime.health != 500 or slime.ward_hits != 0:
		return _fail("two blows glance off the ward")
	game._strike(slime, 50, Vector2.RIGHT, 0.0)
	if slime.health >= 500:
		return _fail("the third blow lands")
	# The shaman casts it by itself in a fight.
	slime.health = 500
	shaman.ward_cooldown = 0.0
	shaman.set_physics_process(true)
	for i in 30:
		await physics_frame
	if slime.ward_hits != 2 or shaman.ward_cooldown <= 0.0:
		return _fail("a fighting shaman wards its ally")
	shaman.free()
	slime.free()

	# --- The wolves' pincer.
	var one: ForestWolf = game.spawn_enemy("wolf", hero.global_position + Vector2(200, 0))
	one.set_physics_process(false)
	if one.pack_size() != 1 or one._shape_chase(Vector2.LEFT, 0.016) != Vector2.LEFT:
		return _fail("a lone wolf runs straight")
	var sides := {}
	var pack: Array = [one]
	for i in 5:
		var wolf: ForestWolf = game.spawn_enemy("wolf", hero.global_position + Vector2(200, 10 + i * 8))
		wolf.set_physics_process(false)
		pack.append(wolf)
	for wolf in pack:
		var bent: Vector2 = wolf._shape_chase(Vector2.LEFT, 0.016)
		if bent.is_equal_approx(Vector2.LEFT) or bent.dot(Vector2.LEFT) < 0.5:
			return _fail("a pack wolf comes at an angle, but still forward")
		sides[wolf.pincer_side()] = true
	if sides.size() != 2:
		return _fail("the pack takes both sides")
	for wolf in pack:
		wolf.free()

	# --- The crab's ambush.
	var crab: CoastCrab = game.spawn_enemy("crab", hero.global_position + Vector2(150, 0))
	if not crab.buried or crab.visual.visible:
		return _fail("the crab waits buried")
	for i in 20:
		await physics_frame
	if not crab.buried or crab.global_position.distance_to(hero.global_position + Vector2(150, 0)) > 1.0:
		return _fail("a buried crab does not move")
	hero.global_position = crab.global_position + Vector2(-40, 0)
	for i in 4:
		await physics_frame
	if crab.buried or not crab.visual.visible:
		return _fail("the crab bursts out when the hero is near")
	crab.free()
	var second: CoastCrab = game.spawn_enemy("crab", hero.global_position + Vector2(300, 0))
	second.set_physics_process(false)
	var hp := second.health
	second.take_damage(5)
	if second.buried or second.health != hp - 5:
		return _fail("a blow on the mound digs the crab out")
	second.free()

	# The bestiary tells the tactics.
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary.json"))
	if not str(book["skeleton"]["attack"]).contains("щит") or not str(book["shaman"]["attack"]).contains("оберег"):
		return _fail("the bestiary explains the new moves")
	if crit_chance < 0.0:
		return _fail("unreachable")
	print("ENEMY TACTICS OK")
	quit(0)
