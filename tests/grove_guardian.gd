extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	game.set("classic_balance", true)
	root.add_child(game)
	await process_frame
	game.quests.start_quest("grove_spirits")
	game.quests.add_progress("grove_spirits", 3)
	game.quests.complete_quest("grove_spirits")
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	var boss: GroveGuardian = null
	for node in game.get_children():
		if node is GroveGuardian:
			boss = node
	if boss == null or boss.health != 160:
		push_error("GUARDIAN TEST FAILED: boss did not spawn")
		quit(1)
		return
	boss.set_physics_process(false)
	boss.take_damage(90)
	if not boss.enraged or boss.health != 70:
		push_error("GUARDIAN TEST FAILED: phase two not activated")
		quit(1)
		return
	boss._shoot_at(game.player.global_position)
	var count: int = 0
	for node in game.get_children():
		if node is EnemyMagicOrb:
			count += 1
	if count != 3:
		push_error("GUARDIAN TEST FAILED: phase two should shoot three orbs")
		quit(1)
		return
	boss.take_damage(70)
	if not game.guardian_defeated:
		push_error("GUARDIAN TEST FAILED: boss defeat not registered")
		quit(1)
		return
	if not game.make_save_snapshot()["world"]["guardian_defeated"]:
		push_error("GUARDIAN TEST FAILED: victory not saved")
		quit(1)
		return
	game._set_region("greenreach", Vector2(130, 210), false)
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	for node in game.get_children():
		if node is GroveGuardian:
			push_error("GUARDIAN TEST FAILED: defeated boss respawned")
			quit(1)
			return
	print("GUARDIAN TEST OK: phases, projectiles, loot/victory and no respawn")
	quit(0)
