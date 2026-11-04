extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var total: int = game.bestiary_entries.size()
	if total != 11:
		push_error("BESTIARY TEST: catalog must list eleven enemies")
		quit(1)
		return
	game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
	if not game.hud.bestiary_visible or game.hud.bestiary_list.get_child_count() != total:
		push_error("BESTIARY TEST: undiscovered entries should be hidden")
		quit(1)
		return
	game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
	var enemy: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy:
			enemy = node
			break
	if enemy == null:
		push_error("BESTIARY TEST: world has no slime")
		quit(1)
		return
	game.player.global_position = enemy.global_position
	game._discover_nearby_enemies()
	if not game.discovered_enemies.has("slime"):
		push_error("BESTIARY TEST: meeting enemy should discover it")
		quit(1)
		return
	game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
	if game.hud.bestiary_list.get_child_count() <= total:
		push_error("BESTIARY TEST: known entry details absent")
		quit(1)
		return
	game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
	var snapshot: Dictionary = game.make_save_snapshot()
	if not snapshot["world"]["discovered"].has("slime"):
		push_error("BESTIARY TEST: discovery not saved")
		quit(1)
		return
	game.discovered_enemies.clear()
	if not game.restore_save_snapshot(snapshot) or not game.discovered_enemies.has("slime"):
		push_error("BESTIARY TEST: discovery not restored")
		quit(1)
		return
	print("BESTIARY TEST OK: hidden entries, discovery, display, save/load")
	quit(0)
