extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var wolf: ForestWolf = load("res://scripts/forest_wolf.gd").new() as ForestWolf
	root.add_child(wolf)
	await process_frame
	wolf.set_physics_process(false)
	wolf.take_elemental_damage(20, "fire")
	if wolf.health != 23:
		push_error("RESISTANCE TEST: wolf fire weakness expected 25 damage")
		quit(1)
		return
	wolf.take_elemental_damage(10, "ice")
	if wolf.health != 15:
		push_error("RESISTANCE TEST: wolf ice resistance expected 8 damage")
		quit(1)
		return
	wolf.apply_slow(0.4, 2.0)
	if not is_equal_approx(wolf.slow_time_left, 1.6):
		push_error("RESISTANCE TEST: slow duration scaling")
		quit(1)
		return
	var shaman: ForestShaman = load("res://scripts/forest_shaman.gd").new() as ForestShaman
	root.add_child(shaman)
	await process_frame
	shaman.set_physics_process(false)
	shaman.take_elemental_damage(20, "lightning")
	if shaman.health != 12:
		push_error("RESISTANCE TEST: shaman lightning weakness")
		quit(1)
		return
	var boss: GroveGuardian = load("res://scripts/grove_guardian.gd").new() as GroveGuardian
	root.add_child(boss)
	await process_frame
	boss.set_physics_process(false)
	boss.take_elemental_damage(20, "fire")
	if boss.health != 147:
		push_error("RESISTANCE TEST: guardian fire resistance")
		quit(1)
		return
	boss.take_elemental_damage(20, "ice")
	if boss.health != 122:
		push_error("RESISTANCE TEST: guardian ice weakness")
		quit(1)
		return
	var bolt: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate() as MagicBolt
	bolt.configure_effect("frostbolt", 0.4, 2.5)
	bolt.setup(Vector2.RIGHT, 10)
	root.add_child(bolt)
	bolt._on_body_entered(wolf)
	if wolf.health != 7:
		push_error("RESISTANCE TEST: frost projectile bypassed resistance")
		quit(1)
		return
	print("RESISTANCE TEST OK: enemy weaknesses, resistant statuses and projectile")
	quit(0)
