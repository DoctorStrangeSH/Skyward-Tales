extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("INVENTORY BUTTON FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	hero.equipment_definitions["test_button_relic"] = {"name": "Реликвия проверки", "description": "+4 к магии", "slot": "relic", "rarity": "rare"}
	hero.add_item("test_button_relic")
	hero.add_item("health_potion", 2)
	var hud: GameHud = game.hud
	hud.toggle_inventory(hero)
	var equip_button: InventoryItemButton = null
	var potion_button: InventoryItemButton = null
	for child in hud.inventory_list.get_children():
		if child is InventoryItemButton:
			if child.item_id == "test_button_relic":
				equip_button = child
			elif child.item_id == "health_potion":
				potion_button = child
	if not _require(equip_button != null and potion_button != null, "HUD did not create item components"):
		return
	if not _require(equip_button.summary.contains("Реликвия проверки") and equip_button.tooltip_text.contains("сравнить характеристики"), "relic tooltip missing"):
		return
	if not _require(potion_button.summary.contains("Зелье здоровья ×2") and not potion_button.tooltip_text.contains("сравнить характеристики"), "consumable display incorrect"):
		return
	var requested_uses: Array[String] = []
	var requested_comparisons: Array[String] = []
	equip_button.use_requested.connect(func(id: String) -> void: requested_uses.append(id))
	equip_button.compare_requested.connect(func(id: String) -> void: requested_comparisons.append(id))
	equip_button.mouse_entered.emit()
	equip_button.pressed.emit()
	if not _require(requested_comparisons == ["test_button_relic"] and requested_uses == ["test_button_relic"], "component signals not forwarded"):
		return
	potion_button.mouse_entered.emit()
	if not _require(requested_comparisons.size() == 1, "consumable unexpectedly requested comparison"):
		return
	print("INVENTORY BUTTON OK: item display, tooltips and signals")
	quit(0)
