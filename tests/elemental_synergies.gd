extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("ELEMENTAL SYNERGY FAILED: " + reason)
		quit(1)
		return false
	return true

func _make_enemy(at: Vector2, health_value: int = 120) -> SlimeEnemy:
	var enemy: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	enemy.max_health = health_value
	enemy.position = at
	root.add_child(enemy)
	return enemy

func _run() -> void:
	var source: SlimeEnemy = _make_enemy(Vector2.ZERO)
	var nearby: SlimeEnemy = _make_enemy(Vector2(42.0, 0.0))
	var distant: SlimeEnemy = _make_enemy(Vector2(90.0, 0.0))
	await process_frame
	source.set_physics_process(false)
	nearby.set_physics_process(false)
	distant.set_physics_process(false)

	source.apply_burning(3, 2.0)
	var lightning: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate() as MagicBolt
	lightning.configure_effect("chain_lightning", 1.0, 0.0)
	lightning.setup(Vector2.RIGHT, 10)
	lightning.chain_targets = 0
	root.add_child(lightning)
	lightning._on_body_entered(source)

	if not _check(source.health == 106, "direct lightning hit plus firestorm bonus should deal 14 damage"):
		return
	if not _check(source.burn_time_left == 2.0 and source.burn_damage == 3, "firestorm must preserve the source burn"):
		return
	if not _check(is_equal_approx(source.firestorm_cooldown_left, 0.75), "firestorm cooldown was not started"):
		return
	if not _check(nearby.burn_damage == 2 and is_equal_approx(nearby.burn_time_left, 1.0), "nearby enemy did not receive weakened one-second burning"):
		return
	if not _check(distant.burn_time_left == 0.0, "enemy outside the 64 px radius was ignited"):
		return
	if not _check(source.combat_feedback.reaction_name == "ОГНЕННАЯ БУРЯ!", "firestorm reaction feedback was not shown"):
		return

	var health_before_repeat: int = source.health
	if not _check(source.react_to_spell("chain_lightning") == 0 and source.health == health_before_repeat, "cooldown allowed an immediate repeated firestorm"):
		return

	# The cooldown expires with the burning update, without creating persistent save state.
	source.burn_tick_timer = 5.0
	source._update_burning(0.8)
	if not _check(source.firestorm_cooldown_left == 0.0, "firestorm cooldown did not expire"):
		return
	if not _check(source.react_to_spell("chain_lightning") == 4, "firestorm did not become available after its cooldown"):
		return

	print("ELEMENTAL SYNERGY OK: lightning ignites nearby enemies from a burning target, bonus damage and cooldown")
	quit(0)
