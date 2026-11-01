extends SceneTree

class DummyTarget extends CharacterBody2D:
	var health: int = 100
	func take_damage(amount: int) -> void:
		health = maxi(0, health - amount)

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("WOLF POUNCE TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var target := DummyTarget.new()
	target.add_to_group("player")
	target.position = Vector2(160, 120)
	target.set_physics_process(true)
	root.add_child(target)

	var wolf_script: Script = load("res://scripts/forest_wolf.gd")
	var wolf: ForestWolf = wolf_script.new() as ForestWolf
	wolf.position = Vector2(100, 120)
	root.add_child(wolf)
	await physics_frame

	if not _check(wolf.brain_state == SlimeEnemy.BrainState.CHASE, "wolf should detect the target"):
		return
	if not _check(wolf.attack_state == SlimeEnemy.AttackState.WINDUP, "wolf should telegraph its pounce before moving"):
		return
	if not _check(target.health == 100, "windup must not deal damage"):
		return

	for _frame in range(45):
		await physics_frame
	if not _check(target.health == 88, "one completed pounce should deal exactly 12 damage"):
		return
	if not _check(wolf.attack_state == SlimeEnemy.AttackState.NONE, "pounce should finish and return to normal movement"):
		return

	for _frame in range(15):
		await physics_frame
	if not _check(target.health == 88, "wolf must not hit repeatedly during its cooldown"):
		return

	print("WOLF POUNCE TEST OK: detection, telegraph, lunge hit, single damage and cooldown")
	quit(0)
