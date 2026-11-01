extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("BURN TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var enemy: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	enemy.max_health = 100
	enemy.position = Vector2(400, 400)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	var bolt: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate() as MagicBolt
	bolt.configure_effect("fireball", 1.0, 0.0)
	bolt.configure_burning(3, 2.0)
	game.add_child(bolt)
	bolt._on_body_entered(enemy)
	if not _check(enemy.health == 82 and enemy.burn_time_left == 2.0, "fireball hit and burn"):
		return
	enemy._update_burning(0.5)
	if not _check(enemy.health == 79, "first fire tick"):
		return
	enemy.apply_burning(3, 2.0)
	enemy._update_burning(1.5)
	if not _check(enemy.health == 70, "periodic ticks without stacking"):
		return
	if not _check(enemy.burn_time_left > 0.0, "repeated hit should refresh burn duration"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	var found: bool = false
	for data in snapshot["world"]["enemies"]:
		if data["position"] == [400.0, 400.0]:
			found = float(data.get("burn_remaining", 0.0)) > 0.0
	if not _check(found, "world save snapshot must persist burn state"):
		return
	enemy._update_burning(0.5)
	if not _check(enemy.burn_time_left == 0.0 and enemy.health == 67, "burn expiration"):
		return
	var low: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	low.max_health = 5
	low.position = Vector2(420, 400)
	game.add_child(low)
	low.set_physics_process(false)
	var defeats: Array[int] = []
	low.defeated.connect(func(xp: int) -> void: defeats.append(xp))
	low.apply_burning(3, 1.0)
	low._update_burning(0.5)
	low._update_burning(0.5)
	low.take_damage(9)
	if not _check(defeats.size() == 1, "burn kill should reward once"):
		return
	print("BURN TEST OK: fireball ignition, nonstacking ticks, duration, save and single kill reward")
	quit(0)
