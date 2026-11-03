extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _assert(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("PAUSE PANEL FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if not _assert(hud.pause_panel is PauseMenuPanel and hud.pause_view == hud.pause_panel, "panel compatibility reference"):
		return
	var box: VBoxContainer = hud.pause_view.get_child(0) as VBoxContainer
	if not _assert(box != null and box.get_child_count() == 7, "pause buttons or heading missing"):
		return
	var calls: Array[String] = []
	hud.pause_save_requested.connect(func() -> void: calls.append("save"))
	hud.pause_load_requested.connect(func() -> void: calls.append("load"))
	hud.pause_menu_requested.connect(func() -> void: calls.append("menu"))
	for index in range(2, 5):
		var button: Button = box.get_child(index) as Button
		button.pressed.emit()
	if not _assert(calls == ["save", "load", "menu"], "signals not forwarded to HUD"):
		return
	hud._set_paused(true)
	if not _assert(hud.pause_view.visible and game.get_tree().paused, "pause did not open"):
		return
	var resume: Button = box.get_child(1) as Button
	resume.pressed.emit()
	if not _assert(not hud.pause_view.visible and not game.get_tree().paused, "resume did not close or unpause"):
		return
	print("PAUSE PANEL OK: layout, forwarded actions and pause state")
	quit(0)
