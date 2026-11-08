extends SceneTree

## Combined hero window: drag a sword from the bag onto the blade slot to
## wear it, drag it back onto the bag to take it off; wrong slots refuse.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("INVENTORY DRAG TEST FAILED: " + reason)
	quit(1)

func _cell(window: InventoryWindow, item_id: String) -> InventoryItemButton:
	for child in window.item_list.get_children():
		if child is InventoryItemButton and child.item_id == item_id:
			return child
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	hero.add_item("iron_sword")
	hero.add_item("leather_armor")
	hero.add_item("wolf_fang", 3)
	game._handle_key(KEY_I)
	var window := game.hud.inventory_view
	if not window.visible or window.tab != "gear" or window.slot_buttons.size() != PlayerCharacter.SLOTS.size():
		return _fail("I opens the hero window with the doll and nine slots")
	var sword := _cell(window, "iron_sword")
	if sword == null or sword.icon == null:
		return _fail("the bag shows the sword as an icon cell")
	var data: Variant = sword._get_drag_data(Vector2.ZERO)
	var blade: EquipSlot = window.slot_buttons["blade"]
	var armor_slot: EquipSlot = window.slot_buttons["armor"]
	if armor_slot._can_drop_data(Vector2.ZERO, data):
		return _fail("a sword does not fit the armour slot")
	if not blade._can_drop_data(Vector2.ZERO, data):
		return _fail("the blade slot accepts the sword")
	blade._drop_data(Vector2.ZERO, data)
	await process_frame
	if hero.equipment.get("blade", "") != "iron_sword":
		return _fail("dropping the sword equips it")
	blade = window.slot_buttons["blade"]
	var back: Variant = blade._get_drag_data(Vector2.ZERO)
	if not window.bag_area._can_drop_data(Vector2.ZERO, back):
		return _fail("the bag accepts a worn item")
	window.bag_area._drop_data(Vector2.ZERO, back)
	await process_frame
	if hero.equipment.get("blade", "") == "iron_sword" or int(hero.inventory.get("iron_sword", 0)) != 1:
		return _fail("dragging the sword back to the bag takes it off")
	var fang := _cell(window, "wolf_fang")
	# Materials can be dragged around the bag (owner's list №22), but no
	# slot takes them.
	var fang_data: Variant = fang._get_drag_data(Vector2.ZERO) if fang != null else null
	if fang == null or fang_data == null or window.slot_buttons["armor"]._can_drop_data(Vector2.ZERO, fang_data) or window.slot_buttons["blade"]._can_drop_data(Vector2.ZERO, fang_data):
		return _fail("materials move in the bag but fit no slot")
	game.hud._on_inventory_filter_selected(3)
	for child in window.item_list.get_children():
		if child is InventoryItemButton and child.item_id != "wolf_fang":
			return _fail("the materials filter shows only materials, not " + child.item_id)
	window.show_tab("skills")
	if not window.skills_view.visible or window.gear_page.visible:
		return _fail("the skills tab replaces the bag")
	game._handle_key(KEY_C)
	if window.visible:
		return _fail("C closes the same window")
	print("INVENTORY DRAG OK: doll, drag to equip, wrong slot refused, drag back to unequip, filters, tabs")
	quit(0)
