extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("SLIME AI TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var enemy_script: Script = load("res://scripts/enemy.gd")
	var slime: SlimeEnemy = enemy_script.new() as SlimeEnemy
	slime.position = Vector2(500, 500)
	root.add_child(slime)
	await physics_frame
	if not _check(slime.home_position == Vector2(500, 500), "Home position was not captured"):
		return
	if not _check(slime.brain_state == SlimeEnemy.BrainState.IDLE, "Initial state is not IDLE"):
		return
	slime._choose_state(100.0)
	if not _check(slime.brain_state == SlimeEnemy.BrainState.CHASE, "Slime does not detect player"):
		return
	slime._choose_state(300.0)
	if not _check(slime.brain_state == SlimeEnemy.BrainState.RETURN, "Slime does not give up chase"):
		return
	slime._choose_state(100.0)
	if not _check(slime.brain_state == SlimeEnemy.BrainState.CHASE, "Slime cannot reacquire player"):
		return
	slime.health = 7
	slime._choose_state(100.0)
	if not _check(slime.brain_state == SlimeEnemy.BrainState.RETREAT, "Low HP does not cause retreat"):
		return
	slime._choose_state(300.0)
	if not _check(slime.brain_state == SlimeEnemy.BrainState.RETURN, "Retreat does not end"):
		return
	print("SLIME AI TEST OK: detection, chase, give-up, reacquire, retreat, return")
	quit(0)
