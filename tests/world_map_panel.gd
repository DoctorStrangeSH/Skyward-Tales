extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("WORLD MAP PANEL FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if not _require(hud.world_map_view is WorldMapPanel, "map component missing"):
		return
	if not _require(hud.world_map_panel == hud.world_map_view and hud.world_map == hud.world_map_view.map_view and hud.world_map_quest == hud.world_map_view.quest_label, "compatibility references missing"):
		return
	if not _require(not hud.world_map_panel.visible, "map starts open"):
		return
	hud.open_world_map("greenfields", Vector2(25, 30), {}, "Найти тропу")
	if not _require(hud.world_map_visible and hud.world_map_panel.visible and hud.world_map_quest.text == "ЗАДАНИЕ: Найти тропу", "map open/quest rendering broken"):
		return
	if not _require(game.get_tree().paused, "world did not pause when map opened"):
		return
	hud.close_world_map()
	if not _require(not hud.world_map_visible and not hud.world_map_panel.visible and not game.get_tree().paused, "map close did not restore gameplay"):
		return
	print("WORLD MAP PANEL OK: component, aliases, pause and quest label")
	quit(0)
