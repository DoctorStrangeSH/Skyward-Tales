extends SceneTree

## Этап 24: weapon mastery — kills with a weapon in hand raise its rank,
## each rank teaches a perk of its own, saves keep it.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("WEAPON MASTERY FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var m := game.mastery
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	if WeaponMastery.KINDS.size() != 6:
		return _fail("six kinds of weapons")
	if hero.weapon_kind() != "sword" or m.rank("sword") != 0:
		return _fail("a sword, untrained")
	for i in 25:
		m.on_kill(false, false)
	if m.rank("sword") != 1:
		return _fail("25 kills: rank I")
	m.on_kill(false, true)
	if m.points("sword") != 35:
		return _fail("a boss is worth 10")
	var foe := game.spawn_enemy("golem", hero.global_position + Vector2(400, 0))
	foe.set_physics_process(false)
	if absf(m.strike_mult(foe, false) - 1.05) > 0.001:
		return _fail("sword I: +5%")
	# Hammer III: finishing blow.
	hero.mastery["hammer"] = 300
	var hammer := "smith_hammer"
	hero.add_item(hammer, 1)
	hero.equip_item(hammer)
	if hero.weapon_kind() != "hammer" or m.rank("hammer") != 3:
		return _fail("a trained hammer in hand")
	foe.health = int(foe.max_health * 0.15)
	m.on_strike(foe, 1)
	if is_instance_valid(foe) and foe.health > 0:
		return _fail("hammer III finishes the weak")
	# Staff III: every fifth spell is free; II: 10% cheaper.
	hero.mastery["staff"] = 300
	var staff := "apprentice_staff"
	hero.add_item(staff, 1)
	hero.equip_item(staff)
	var costs: Array = []
	for i in 5:
		costs.append(m.mana_cost(20))
	if costs != [18, 18, 18, 18, 0]:
		return _fail("staff costs: %s" % str(costs))
	# Saves keep it.
	var snapshot := game.make_save_snapshot()
	hero.mastery.clear()
	if not game.restore_save_snapshot(snapshot) or game.player.mastery.get("sword", 0) != 35:
		return _fail("mastery survives a save")
	if not game.mastery.summary().contains("Посох"):
		return _fail("the tree shows the weapon in hand: " + game.mastery.summary())
	print("WEAPON MASTERY OK")
	quit()
