extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("EQUIPMENT PANEL FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	var hud: GameHud = game.hud
	if not _require(hud.comparison_panel is EquipmentComparisonPanel, "HUD does not use extracted panel"):
		return
	if not _require(hud.comparison_grid == hud.comparison_view.stats_grid, "compatibility grid alias missing"):
		return
	hud._show_equipment_comparison(hero, "leather_armor")
	if not _require(hud.comparison_view.visible, "valid equipment does not open panel"):
		return
	if not _require(hud.comparison_title.text.contains("Кожаная броня"), "title not rendered"):
		return
	hud._show_equipment_comparison(hero, "health_potion")
	if not _require(not hud.comparison_view.visible, "non-equipment did not close panel"):
		return
	print("EQUIPMENT PANEL OK: component, compatibility aliases and visibility")
	quit(0)
