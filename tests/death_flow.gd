extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func fail(message: String) -> void:
	push_error("DEATH FLOW TEST FAILED: " + message)
	quit(1)

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://death_flow_test.json"
	game.player.health = 64
	if not game.save_game():
		fail("could not create pre-death save")
		return
	game.player.take_damage(999)
	if not game.game_over or not game.hud.defeat_visible or not paused:
		fail("death did not open defeat screen and pause world")
		return
	if game.save_game():
		fail("save was allowed after death and could overwrite living progress")
		return
	if game.hud.defeat_load_button.disabled:
		fail("valid save was not offered on defeat screen")
		return
	if not game.load_game():
		fail("load from defeat screen failed")
		return
	if game.game_over or game.hud.defeat_visible or paused:
		fail("successful recovery did not resume gameplay")
		return
	if game.player.health != 64:
		fail("loaded player health did not match saved health")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.player.take_damage(999)
	if not game.game_over or not game.hud.defeat_visible or not game.hud.defeat_load_button.disabled:
		fail("missing save should keep defeat screen and disable load")
		return
	if game.load_game():
		fail("load unexpectedly succeeded without save")
		return
	if not paused or not game.hud.defeat_visible:
		fail("failed load should not dismiss defeat screen")
		return
	if not game.hud.defeat_restart_requested.is_connected(game._restart_run):
		fail("restart button is not connected")
		return
	if not game.hud.defeat_menu_requested.is_connected(game._go_to_title):
		fail("main menu button is not connected")
		return
	print("DEATH FLOW TEST OK: one-shot death, pause, safe save, recovery, missing-save handling")
	paused = false
	quit(0)
