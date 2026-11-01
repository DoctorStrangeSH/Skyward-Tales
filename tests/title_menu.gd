extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu: Control = load("res://scenes/title_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	if menu.continue_button == null or not menu.continue_button.disabled:
		push_error("MENU TEST FAILED: continue should be disabled without valid save")
		quit(1)
		return
	root.remove_child(menu)
	menu.queue_free()
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hud._set_paused(true)
	if not game.hud.pause_panel.visible or not paused:
		push_error("MENU TEST FAILED: pause panel or pause flag")
		quit(1)
		return
	game.hud._set_paused(false)
	if game.hud.pause_panel.visible or paused:
		push_error("MENU TEST FAILED: resume")
		quit(1)
		return
	print("MENU TEST OK: main menu, unavailable continue, pause, resume")
	quit(0)
