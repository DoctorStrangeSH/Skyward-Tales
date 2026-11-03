extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("INVENTORY WINDOW FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hud: GameHud = game.hud
	if not _require(hud.inventory_view is InventoryWindow and hud.inventory_panel == hud.inventory_view, "HUD panel alias missing"):
		return
	if not _require(hud.inventory_list == hud.inventory_view.item_list and hud.equipment_list == hud.inventory_view.equipment_list, "list aliases missing"):
		return
	if not _require(hud.inventory_filter == hud.inventory_view.filter_button and hud.inventory_sort == hud.inventory_view.sort_button, "filter/sort aliases missing"):
		return
	if not _require(hud.inventory_filter.get_item_count() == 3 and hud.inventory_sort.get_item_count() == 3, "filter/sort choices changed"):
		return
	if not _require(not hud.inventory_view.visible, "inventory starts visible"):
		return
	hud.toggle_inventory(game.player)
	if not _require(hud.inventory_view.visible, "inventory did not open"):
		return
	hud.inventory_filter.item_selected.emit(1)
	if not _require(hud.inventory_filter_index == 1, "filter event not forwarded"):
		return
	hud.inventory_sort.item_selected.emit(2)
	if not _require(hud.inventory_sort_index == 2, "sort event not forwarded"):
		return
	hud.toggle_inventory(game.player)
	if not _require(not hud.inventory_view.visible, "inventory did not close"):
		return
	print("INVENTORY WINDOW OK: widget hierarchy, aliases and controls")
	quit(0)
