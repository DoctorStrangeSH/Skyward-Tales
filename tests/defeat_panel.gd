extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("DEFEAT PANEL FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if not _check(hud.defeat_panel is DefeatPanel and hud.defeat_hint_label == hud.defeat_view.hint_label and hud.defeat_load_button == hud.defeat_view.load_button, "compatibility aliases"):
		return
	var actions: Array[String] = []
	hud.defeat_restart_requested.connect(func() -> void: actions.append("restart"))
	hud.defeat_load_requested.connect(func() -> void: actions.append("load"))
	hud.defeat_menu_requested.connect(func() -> void: actions.append("menu"))
	hud.show_defeat(false)
	if not _check(hud.defeat_visible and hud.defeat_view.visible and hud.defeat_load_button.disabled and hud.defeat_hint_label.text.contains("нет"), "no-save state"):
		return
	hud.show_defeat(true)
	if not _check(not hud.defeat_load_button.disabled and hud.defeat_hint_label.text.contains("найдено"), "save available state"):
		return
	var box: VBoxContainer = hud.defeat_view.get_child(0) as VBoxContainer
	for index in range(3, 6):
		var button: Button = box.get_child(index) as Button
		button.pressed.emit()
	if not _check(actions == ["restart", "load", "menu"], "actions not routed"):
		return
	hud.hide_defeat()
	if not _check(not hud.defeat_visible and not hud.defeat_view.visible, "panel did not hide"):
		return
	print("DEFEAT PANEL OK")
	quit(0)
