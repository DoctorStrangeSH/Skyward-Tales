extends SceneTree

## Этап 24: the Starfall Isle — reached by ship only on the Night of
## Starfall; stars fall and leave fragments (12 a year); the Star Guardian.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("STARFALL FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.sky_battle.enabled = false
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	var ship := game.ship
	game.director.set_flag(SkyShip.READY_FLAG)
	game.day_night.day = 3
	if ship.blocked("starfall_isle").is_empty() or ship.fly_now("starfall_isle"):
		return _fail("not on an ordinary day")
	game.day_night.day = int(GameCalendar.FESTIVALS["starfall"]["day"])
	if not ship.blocked("starfall_isle").is_empty() or not ship.fly_now("starfall_isle"):
		return _fail("the ship flies there on the Night of Starfall: " + ship.blocked("starfall_isle"))
	for i in 14:
		await physics_frame
	if game.current_region != "starfall_isle":
		return _fail("landed on the isle")
	var map := game.world.get_world_2d().navigation_map
	var dock := SkywardGame._vec(RegionCatalog.get_region("starfall_isle")["dock"])
	for spot in [dock + Vector2(0, 26), StarfallIsle.CRATER]:
		if NavigationServer2D.map_get_closest_point(map, spot).distance_to(spot) > 30.0:
			return _fail("one can stand at %s" % str(spot))
	var guardian: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("star_guardian"):
			guardian = node
	if guardian == null:
		return _fail("the Star Guardian waits by the crater")
	# A star falls and leaves a fragment.
	game.starfall.fall(hero.global_position + Vector2(40, 0))
	await create_timer(CrystalStrike.WARN + 0.2).timeout
	var fragments := game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot and n.item_id == "star_fragment")
	if fragments.is_empty() or game.starfall.stars_left() != StarfallIsle.STARS - 1:
		return _fail("a fragment where the star fell")
	for i in StarfallIsle.STARS:
		game.starfall.fall(hero.global_position + Vector2(60, 0))
	if game.starfall.stars_left() != 0:
		return _fail("no more than twelve a year")
	# The guardian falls: essence and gold, once a year.
	guardian.take_damage(99999999)
	for i in 4:
		await process_frame
	if not bool(game.starfall.night.get("guardian", false)) or int(game.achievements.stats.get("star_guardians", 0)) != 1:
		return _fail("the guardian is beaten and remembered")
	var snapshot := game.make_save_snapshot()
	game.starfall.night.clear()
	if not game.restore_save_snapshot(snapshot) or not bool(game.starfall.night.get("guardian", false)):
		return _fail("the night survives a save")
	print("STARFALL OK")
	quit()
