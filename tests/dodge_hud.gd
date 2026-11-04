extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var ui: GameHud = game.hud
	if ui.dodge_label == null or ui.dodge_cooldown_bar == null:
		push_error("DODGE HUD TEST: panel not created")
		quit(1)
		return
	ui.update_dodge(0.5, 0.85, false)
	if not ui.dodge_label.text.contains("ОТКАТ") or ui.dodge_cooldown_bar.value >= 1.0:
		push_error("DODGE HUD TEST: cooldown not shown")
		quit(1)
		return
	ui.update_dodge(0.0, 0.85, false)
	if not ui.dodge_label.text.contains("ГОТОВО") or ui.dodge_cooldown_bar.value < 0.99:
		push_error("DODGE HUD TEST: ready state not shown")
		quit(1)
		return
	game.player.add_item("ancient_relic")
	ui.refresh_inventory(game.player)
	var found: bool = false
	for button in ui.inventory_list.get_children():
		if button is InventoryItemButton and button.summary.contains("Древний артефакт"):
			found = true
			if button.can_use:
				push_error("DODGE HUD TEST: boss trophy should not be consumable")
				quit(1)
				return
	if not found:
		push_error("DODGE HUD TEST: boss relic label missing")
		quit(1)
		return
	print("DODGE HUD TEST OK: cooldown, ready state, relic label")
	quit(0)
