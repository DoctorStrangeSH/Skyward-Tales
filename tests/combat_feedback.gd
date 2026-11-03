extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemy: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	root.add_child(enemy)
	await process_frame
	if enemy.combat_feedback == null:
		push_error("FEEDBACK TEST FAILED: health indicator absent")
		quit(1)
		return
	enemy.take_damage(9)
	if enemy.combat_feedback.health != 23 or enemy.combat_feedback.damage_amount != 9 or enemy.combat_feedback.damage_timer <= 0.0:
		push_error("FEEDBACK TEST FAILED: damage feedback incorrect")
		quit(1)
		return
	enemy.attack_windup_duration = 0.4
	enemy._start_special_attack(Vector2.RIGHT)
	if not enemy.combat_feedback.warning:
		push_error("FEEDBACK TEST FAILED: windup warning absent")
		quit(1)
		return
	enemy._cancel_special_attack()
	if enemy.combat_feedback.warning:
		push_error("FEEDBACK TEST FAILED: warning not cleared")
		quit(1)
		return
	var boss: GroveGuardian = load("res://scripts/grove_guardian.gd").new() as GroveGuardian
	root.add_child(boss)
	await process_frame
	boss.take_damage(85)
	if not boss.enraged or not boss.combat_feedback.elite or boss.combat_feedback.health != 75 or not boss.combat_feedback.warning:
		push_error("FEEDBACK TEST FAILED: guardian warning, health or elite style")
		quit(1)
		return
	print("COMBAT FEEDBACK TEST OK: health, damage numbers, windup and guardian phase")
	quit(0)
