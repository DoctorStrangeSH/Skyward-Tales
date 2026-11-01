extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	var player: PlayerCharacter = game.player
	player.add_item("health_potion", 2)
	player.take_damage(50)
	hud.toggle_inventory(player)
	if not hud.inventory_open or not hud.inventory_panel.visible or hud.inventory_list.get_child_count() < 2:
		push_error("INVENTORY TEST FAILED: panel did not open or populate")
		quit(1)
		return
	hud.inventory_use_requested.emit("health_potion")
	if player.health != 85 or int(player.inventory.get("health_potion", 0)) != 1:
		push_error("INVENTORY TEST FAILED: mouse action did not heal/decrement")
		quit(1)
		return
	hud.toggle_inventory(player)
	if hud.inventory_open or hud.inventory_panel.visible:
		push_error("INVENTORY TEST FAILED: panel did not close")
		quit(1)
		return
	print("INVENTORY TEST OK: open, item display, use, close")
	quit(0)
