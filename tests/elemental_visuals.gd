extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemy: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	enemy.max_health = 100
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.apply_burning(3, 2.0)
	if not enemy.combat_feedback.burning:
		push_error("STATUS VISUAL TEST: fire indicator not enabled")
		quit(1)
		return
	enemy.react_to_spell("frostbolt")
	if enemy.combat_feedback.burning or enemy.combat_feedback.reaction_name != "ПАР!":
		push_error("STATUS VISUAL TEST: steam reaction not shown")
		quit(1)
		return
	enemy.apply_slow(0.4, 2.0)
	if not enemy.combat_feedback.chilled:
		push_error("STATUS VISUAL TEST: ice indicator not enabled")
		quit(1)
		return
	enemy.react_to_spell("chain_lightning")
	if enemy.combat_feedback.chilled or enemy.combat_feedback.reaction_name != "КРИСТАЛЬНАЯ ЦЕПЬ!":
		push_error("STATUS VISUAL TEST: shock reaction not shown")
		quit(1)
		return
	enemy.apply_burning(3, 0.5)
	enemy._update_burning(0.5)
	if enemy.combat_feedback.burning:
		push_error("STATUS VISUAL TEST: fire indicator did not expire")
		quit(1)
		return
	print("STATUS VISUAL TEST OK: fire, ice, steam, shock, expiration")
	quit(0)
