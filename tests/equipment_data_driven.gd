extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("DATA-DRIVEN EQUIPMENT TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	hero.equipment_definitions["test_focus"] = {
		"name": "Фокус испытания",
		"description": "+2 урона всем заклинаниям",
		"slot": "relic",
		"rarity": "rare",
		"spell_bonus": {"*": 2}
	}
	hero.add_item("test_focus")
	game.hud.toggle_inventory(hero)
	if not _require(game.hud.inventory_list.get_child_count() == 1, "unknown catalog item is not listed"):
		return
	var item_button: Button = game.hud.inventory_list.get_child(0) as Button
	if not _require(item_button != null and item_button.text.contains("Фокус испытания"), "catalog name is not shown"):
		return
	if not _require(item_button.tooltip_text.contains("экипировать"), "catalog action hint is missing"):
		return
	game._on_inventory_use("test_focus")
	if not _require(str(hero.equipment.get("relic", "")) == "test_focus", "new catalog item was not equipped"):
		return
	if not _require(hero.get_spell_bonus("fireball") == 2, "new catalog item bonus was not applied"):
		return
	if not _require(game.hud.inventory_list.get_child_count() == 1 and game.hud.inventory_list.get_child(0).text == "Сумка пуста.", "inventory did not refresh after equip"):
		return
	game._on_inventory_unequip("relic")
	if not _require(str(hero.equipment.get("relic", "")).is_empty(), "new catalog item was not unequipped"):
		return
	if not _require(int(hero.inventory.get("test_focus", 0)) == 1, "unequipped item was not returned"):
		return
	if not _require(game.hud.inventory_list.get_child_count() == 1 and game.hud.inventory_list.get_child(0).text.contains("Фокус испытания"), "inventory did not refresh after unequip"):
		return
	print("DATA-DRIVEN EQUIPMENT TEST OK: catalog discovery, equip, effect, unequip and UI refresh")
	quit(0)
