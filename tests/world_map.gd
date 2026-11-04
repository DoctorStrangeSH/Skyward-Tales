extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.global_position = Vector2(560, 520)
	game._update_minimap()
	var markers: Dictionary = game.discovered_landmarks.get(game.current_region, {})
	game.hud.open_world_map(game.current_region, game.player.global_position, markers, game.quests.get_active_summary())
	if not game.hud.world_map_visible or not game.hud.world_map_panel.visible or not paused:
		push_error("WORLD MAP TEST: opening did not show the map and pause")
		quit(1)
		return
	if game.hud.world_map.known_landmarks.is_empty() or not game.hud.world_map_quest.text.contains("ЗАДАНИЕ"):
		push_error("WORLD MAP TEST: known places or quest not displayed")
		quit(1)
		return
	game.hud.close_world_map()
	if game.hud.world_map_visible or paused:
		push_error("WORLD MAP TEST: closing did not resume world")
		quit(1)
		return
	game._set_region("moonlit_grove", Vector2(250, 420), false)
	game._update_minimap()
	game.hud.open_world_map(game.current_region, game.player.global_position, game.discovered_landmarks.get(game.current_region, {}), game.quests.get_active_summary())
	if game.hud.world_map.region_id != "moonlit_grove":
		push_error("WORLD MAP TEST: region change not reflected")
		quit(1)
		return
	game.hud.close_world_map()
	print("WORLD MAP TEST OK: quest summary, known places, pause/close and region")
	quit(0)
