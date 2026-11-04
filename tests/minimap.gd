extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.hud.minimap == null:
		push_error("MINIMAP TEST: map missing")
		quit(1)
		return
	if not game.hud.minimap._map_point(Vector2(960, 640)).distance_to(Vector2(66, 64)) < 0.01:
		push_error("MINIMAP TEST: invalid world-to-map scaling")
		quit(1)
		return
	game.player.global_position = Vector2(560, 520)
	game._update_minimap()
	var green: Dictionary = game.discovered_landmarks.get("greenreach", {})
	if green.is_empty() or game.hud.minimap.known_landmarks.is_empty():
		push_error("MINIMAP TEST: nearest NPC must be discovered")
		quit(1)
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	game.discovered_landmarks.clear()
	if not game.restore_save_snapshot(snapshot):
		push_error("MINIMAP TEST: save restore failed")
		quit(1)
		return
	if game.discovered_landmarks.get("greenreach", {}).is_empty():
		push_error("MINIMAP TEST: known landmarks not restored")
		quit(1)
		return
	game._set_region("moonlit_grove", Vector2(250, 420), false)
	game._update_minimap()
	if game.hud.minimap.region_id != "moonlit_grove":
		push_error("MINIMAP TEST: region did not update")
		quit(1)
		return
	if game.discovered_landmarks.get("moonlit_grove", {}).is_empty():
		push_error("MINIMAP TEST: new region NPC was not discovered")
		quit(1)
		return
	print("MINIMAP TEST OK: coordinates, discovery, persistence and region travel")
	quit(0)
