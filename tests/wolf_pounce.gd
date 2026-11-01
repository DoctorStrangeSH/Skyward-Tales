extends SceneTree

class TestDriver extends Node:
	signal finished(success: bool)
	var player: PlayerCharacter
	var wolf: ForestWolf
	var frame_count: int = 0

	func _physics_process(delta: float) -> void:
		# Drive the wolf explicitly from this physics callback so the test has a fixed clock.
		wolf._physics_process(delta)
		frame_count += 1
		if frame_count == 1:
			if wolf.brain_state != SlimeEnemy.BrainState.CHASE or wolf.attack_state != SlimeEnemy.AttackState.WINDUP:
				push_error("WOLF POUNCE TEST FAILED: wolf did not detect and telegraph")
				finished.emit(false)
				set_physics_process(false)
				return
			if player.health != 100:
				push_error("WOLF POUNCE TEST FAILED: windup dealt damage")
				finished.emit(false)
				set_physics_process(false)
				return
		if frame_count == 45:
			if player.health != 88 or wolf.attack_state != SlimeEnemy.AttackState.NONE:
				push_error("WOLF POUNCE TEST FAILED: pounce did not deal one 12-damage hit and finish")
				finished.emit(false)
				set_physics_process(false)
				return
		if frame_count == 60:
			if player.health != 88:
				push_error("WOLF POUNCE TEST FAILED: wolf hit again before cooldown elapsed")
				finished.emit(false)
			else:
				print("WOLF POUNCE TEST OK: detection, telegraph, lunge hit, single damage and cooldown")
				finished.emit(true)
			set_physics_process(false)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: PlayerCharacter = player_scene.instantiate() as PlayerCharacter
	player.position = Vector2(600, 600)
	root.add_child(player)

	var wolf_script: Script = load("res://scripts/forest_wolf.gd")
	var wolf: ForestWolf = wolf_script.new() as ForestWolf
	wolf.position = Vector2(540, 600)
	root.add_child(wolf)
	await process_frame
	wolf.set_physics_process(false)

	var driver := TestDriver.new()
	driver.player = player
	driver.wolf = wolf
	root.add_child(driver)
	var passed: bool = await driver.finished
	quit(0 if passed else 1)
