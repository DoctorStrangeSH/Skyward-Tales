extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("ELEMENT REACTION FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var enemy: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	enemy.max_health = 120
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.apply_burning(3, 2.0)
	var frost: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate() as MagicBolt
	frost.configure_effect("frostbolt", 0.4, 2.5)
	frost.setup(Vector2.RIGHT, 10)
	root.add_child(frost)
	frost._on_body_entered(enemy)
	if not _check(enemy.health == 102 and enemy.burn_time_left == 0.0 and enemy.slow_time_left == 2.5, "steam must consume burn, add 8 damage and slow"):
		return
	var lightning: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate() as MagicBolt
	lightning.configure_effect("chain_lightning", 1.0, 0.0)
	lightning.setup(Vector2.RIGHT, 15)
	root.add_child(lightning)
	lightning._on_body_entered(enemy)
	if not _check(enemy.health == 81 and enemy.slow_time_left == 0.0 and enemy.slow_factor == 1.0, "shock must consume slow and deal 6 bonus damage"):
		return
	if not _check(enemy.react_to_spell("chain_lightning") == 0, "no repeat reaction without status"):
		return
	print("ELEMENT REACTIONS OK: steam, shock, status consumption and no duplicate")
	quit(0)
