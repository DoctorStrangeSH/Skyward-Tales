extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("INVENTORY POPULATE FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	var hud: GameHud = game.hud
	hero.add_item("health_potion", 2)
	hero.add_item("leather_armor")
	hud.toggle_inventory(hero)
	if not _check(hud.inventory_list.get_child_count() == 2, "items were not rendered"):
		return
	if not _check(hud.equipment_list.get_child_count() == 5, "equipment slots were not rendered"):
		return
	var item_button: InventoryItemButton = null
	for child in hud.inventory_list.get_children():
		if child is InventoryItemButton and child.item_id == "leather_armor":
			item_button = child
	if not _check(item_button != null, "equipment button missing"):
		return
	item_button.mouse_entered.emit()
	if not _check(hud.comparison_panel.visible, "comparison signal not forwarded"):
		return
	hud.inventory_filter.item_selected.emit(2)
	if not _check(hud.inventory_list.get_child_count() == 1, "filter not reflected in rendered items"):
		return
	if not _check(hud.inventory_list.get_child(0) is InventoryItemButton and hud.inventory_list.get_child(0).item_id == "health_potion", "wrong filtered item"):
		return
	print("INVENTORY POPULATE OK: slots, items, hover and filtering")
	quit(0)
