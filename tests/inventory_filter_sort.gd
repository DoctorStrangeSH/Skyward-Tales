extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("INVENTORY FILTER/SORT TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _item_button_text(hud: GameHud, index: int) -> String:
	if index < 0 or index >= hud.inventory_list.get_child_count():
		return ""
	var button: Button = hud.inventory_list.get_child(index) as Button
	return button.text if button != null else ""

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: PlayerCharacter = game.player
	player.equipment_definitions["test_common_staff"] = {
		"name": "Посох испытания",
		"description": "+1 к урону",
		"slot": "weapon",
		"rarity": "common"
	}
	player.equipment_definitions["test_uncommon_armor"] = {
		"name": "Броня хранителя",
		"description": "+1 к защите",
		"slot": "armor",
		"rarity": "uncommon"
	}
	player.equipment_definitions["test_rare_relic"] = {
		"name": "Реликвия звёзд",
		"description": "+1 к магии",
		"slot": "relic",
		"rarity": "rare"
	}
	player.add_item("test_common_staff")
	player.add_item("test_uncommon_armor")
	player.add_item("test_rare_relic")
	player.add_item("health_potion", 2)
	player.add_item("mana_potion")
	var hud: GameHud = game.hud
	hud.toggle_inventory(player)
	if not _require(hud.inventory_list.get_child_count() == 5, "all filter should show every owned item"):
		return

	hud.inventory_filter.select(1)
	hud.inventory_filter.item_selected.emit(1)
	if not _require(hud.inventory_list.get_child_count() == 3, "equipment filter should show only gear"):
		return
	for index in range(hud.inventory_list.get_child_count()):
		var text: String = _item_button_text(hud, index)
		if not _require(not text.contains("Зелье здоровья") and not text.contains("Зелье маны"), "consumable leaked into equipment filter"):
			return

	hud.inventory_filter.select(2)
	hud.inventory_filter.item_selected.emit(2)
	if not _require(hud.inventory_list.get_child_count() == 2, "consumables filter should show both potion stacks"):
		return
	if not _require(_item_button_text(hud, 0).contains("Зелье здоровья") and _item_button_text(hud, 1).contains("Зелье маны"), "consumables filter returned unexpected items"):
		return

	hud.inventory_filter.select(0)
	hud.inventory_filter.item_selected.emit(0)
	hud.inventory_sort.select(1)
	hud.inventory_sort.item_selected.emit(1)
	if not _require(_item_button_text(hud, 0).contains("Броня хранителя"), "name sort should place Броня before other items"):
		return
	if not _require(_item_button_text(hud, 1).contains("Зелье здоровья"), "name sort should use localized display names"):
		return

	hud.inventory_sort.select(2)
	hud.inventory_sort.item_selected.emit(2)
	if not _require(_item_button_text(hud, 0).contains("Реликвия звёзд"), "rarity sort should put rare gear first"):
		return
	if not _require(_item_button_text(hud, 1).contains("Броня хранителя"), "rarity sort should put uncommon gear after rare"):
		return
	if not _require(_item_button_text(hud, 2).contains("Посох испытания"), "rarity sort should put common gear after uncommon"):
		return
	print("INVENTORY FILTER/SORT TEST OK: categories, localized name order and rarity priority")
	quit(0)
