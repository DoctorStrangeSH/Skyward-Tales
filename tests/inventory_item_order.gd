extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, details: String) -> bool:
	if not value:
		push_error("INVENTORY ORDER FAILED: " + details)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	hero.equipment_definitions["test_common"] = {"slot": "weapon", "name": "Яблочный посох", "rarity": "common"}
	hero.equipment_definitions["test_rare"] = {"slot": "relic", "name": "Астральная реликвия", "rarity": "rare"}
	hero.equipment_definitions["test_uncommon"] = {"slot": "armor", "name": "Волчья броня", "rarity": "uncommon"}
	if not _expect(InventoryItemOrder.category(hero, "test_common", ["health_potion"]) == "equipment", "gear category"):
		return
	if not _expect(InventoryItemOrder.category(hero, "health_potion", ["health_potion"]) == "consumable", "consumable category"):
		return
	if not _expect(InventoryItemOrder.category(hero, "unknown", ["health_potion"]) == "other", "unknown category"):
		return
	var ids: Array[String] = ["test_common", "test_rare", "test_uncommon"]
	InventoryItemOrder.sort_items(hero, ids, 2, {})
	if not _expect(ids == ["test_rare", "test_uncommon", "test_common"], "rarity ordering"):
		return
	ids = ["test_common", "test_rare", "test_uncommon"]
	InventoryItemOrder.sort_items(hero, ids, 1, {})
	if not _expect(ids == ["test_rare", "test_uncommon", "test_common"], "localized alphabetical ordering"):
		return
	ids = ["test_common", "test_rare", "test_uncommon"]
	InventoryItemOrder.sort_items(hero, ids, 0, {})
	if not _expect(ids == ["test_common", "test_rare", "test_uncommon"], "default order must remain unchanged"):
		return
	var hud: GameHud = game.hud
	if not _expect(hud._inventory_rarity_rank(hero, "test_rare") == 3, "HUD delegates rarity rank"):
		return
	print("INVENTORY ORDER OK")
	quit(0)
