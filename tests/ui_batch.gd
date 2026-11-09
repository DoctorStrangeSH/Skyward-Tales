extends SceneTree

## Interface batch: skills dragged onto the bar, the action bar (mouse
## slots, menu buttons, experience), bag categories, the crafting window.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("UI TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hud := game.hud
	var hero := game.player
	hero.level = 10

	# Drag a skill onto the action bar.
	var slot: HotbarSlot = hud.action_bar.slots[2]
	if not slot._can_drop_data(Vector2.ZERO, {"skill_id": "spirit_wolf", "from_slot": -1}):
		return _fail("skill slots accept dragged skills")
	slot._drop_data(Vector2.ZERO, {"skill_id": "spirit_wolf", "from_slot": -1})
	if str(hero.skill_slots[2]) != "spirit_wolf":
		return _fail("dropping a skill puts it on the bar")
	if (hud.action_bar.slots[5] as HotbarSlot)._can_drop_data(Vector2.ZERO, {"skill_id": "lunge"}):
		return _fail("potion slots don't take skills")

	# The skills tab: cards drag, bar slots swap and clear.
	hud.toggle_inventory(hero)
	hud.inventory_view.show_tab("skills")
	var page := hud.inventory_view.skills_view
	var card: SkillCard = page.skill_rows["lunge"]
	if card._get_drag_data(Vector2.ZERO) == null:
		return _fail("an open skill can be dragged")
	var locked: SkillCard = page.skill_rows["volley"]
	if locked._get_drag_data(Vector2.ZERO) != null:
		return _fail("a locked skill can't")
	(page.bar_slots[0] as SkillBarSlot)._drop_data(Vector2.ZERO, {"skill_id": "spirit_wolf", "from_slot": 2})
	if str(hero.skill_slots[0]) != "spirit_wolf":
		return _fail("drop on a bar slot in the hero window")
	page = hud.inventory_view.skills_view
	var first: SkillBarSlot = page.bar_slots[0]
	first.cleared.emit(0)
	if not str(hero.skill_slots[0]).is_empty():
		return _fail("dragging a skill off the bar clears the slot")
	hud.close_top_window()

	# Bag categories.
	hero.add_item("health_potion", 3)
	hero.add_item("wood", 4)
	hero.add_item("iron_sword", 1)
	hud.toggle_inventory(hero)
	var window := hud.inventory_view
	if window.category_tabs.size() != 4 or str((window.category_tabs[3] as Button).text) == "0":
		return _fail("category tabs with counts")
	(window.category_tabs[2] as Button).pressed.emit()
	for child in window.item_list.get_children():
		if child is InventoryItemButton and InventoryItemOrder.category(hero, child.item_id, ["health_potion", "mana_potion"]) != "consumable":
			return _fail("the consumables tab shows only consumables")
	if window.item_list.get_child_count() < InventoryWindow.MIN_ROWS * InventoryWindow.GRID_COLUMNS:
		return _fail("empty cells fill the bag")
	hud.close_top_window()

	# Action bar.
	await process_frame
	await process_frame
	if hud.action_bar.mouse_slots.size() != 2 or (hud.action_bar.mouse_slots[0] as HotbarSlot).key_text != "ЛКМ":
		return _fail("mouse slots on the bar")
	(hud.menu_tabs.buttons["journal"] as Button).pressed.emit()
	if not hud.journal_visible:
		return _fail("the journal button opens the journal")
	hud.close_top_window()
	hud.update_status(hero, game.quests)
	if hud.action_bar.xp_label.text.is_empty():
		return _fail("experience on the bar")

	# Crafting window.
	hero.add_item("slime_gel", 4)
	hero.add_item("healroot", 2)
	game._handle_key(KEY_B)
	if not hud.crafting_visible or hud.dialogue_visible:
		return _fail("B opens the crafting window")
	var crafting := hud.crafting_view
	if crafting.craftable_times("hand_gel_potion") != 2:
		return _fail("how many times: %d" % crafting.craftable_times("hand_gel_potion"))
	var potions := int(hero.inventory.get("health_potion", 0))
	crafting.craft_requested.emit("hand_gel_potion", 2)
	if int(hero.inventory.get("health_potion", 0)) != potions + 2 or not hud.crafting_visible:
		return _fail("make all, the window stays")
	crafting.category = "equipment"
	crafting._rebuild_list()
	if crafting.rows.has("hand_gel_potion"):
		return _fail("categories filter recipes")
	hud.close_top_window()
	if hud.crafting_visible or not hero.is_physics_processing():
		return _fail("Esc closes crafting")
	game._handle_key(KEY_B)
	game._handle_key(KEY_B)
	if hud.crafting_visible:
		return _fail("B toggles crafting")

	# Wheel switches spells.
	var before := game.selected_spell_id
	game.cycle_spell(1)
	if game.selected_spell_id == before:
		return _fail("the wheel switches spells")
	print("UI OK: skill drag, action bar, bag categories, crafting window, spell wheel")
	quit(0)
