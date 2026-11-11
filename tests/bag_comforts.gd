extends SceneTree

## Review item 6: comforts of the bag and crafting — favourite / junk marks,
## selling all junk at once, protection of favourites, "where to get it"
## hints, a pinned recipe and an auto-pinned building on the screen.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("BAG COMFORTS FAILED: " + reason)
	quit(1)

func _titles(game: SkywardGame) -> String:
	var text := ""
	for entry in game.pin.tracker_entries():
		text += "%s %d/%d|" % [entry["title"], entry["progress"], entry["target"]]
	return text

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var shop := game.merchant_shop

	# Marks cycle: none → favourite → junk → none.
	hero.add_item("slime_gel", 5)
	hero.add_item("wolf_fang", 3)
	hero.add_item("copper_ore", 4)
	if hero.cycle_item_mark("copper_ore") != "fav" or hero.cycle_item_mark("slime_gel") != "fav" or hero.cycle_item_mark("slime_gel") != "junk":
		return _fail("marks cycle")
	hero.cycle_item_mark("wolf_fang")
	hero.cycle_item_mark("wolf_fang")
	# A favourite is not for sale; junk goes in one go.
	if shop.sellable_count(hero, "copper_ore") != 0:
		return _fail("a favourite is not sold")
	for offer in shop.get_sell_offers(hero, 0):
		if str(offer["id"]) == "copper_ore":
			return _fail("a favourite is not offered for sale")
	var total: Dictionary = shop.junk_total(hero, 0)
	var expected := 5 * shop.get_sell_price("slime_gel", 0, hero) + 3 * shop.get_sell_price("wolf_fang", 0, hero)
	if int(total["count"]) != 8 or int(total["gold"]) != expected or expected <= 0:
		return _fail("junk is counted: %s" % total)
	var gold := hero.gold
	game._on_dialogue_choice_selected("merchant_sell:junk")
	if hero.gold != gold + expected or hero.inventory.has("slime_gel") or hero.inventory.has("wolf_fang"):
		return _fail("all junk is sold at once: %d" % (hero.gold - gold))
	if int(hero.inventory.get("copper_ore", 0)) != 4:
		return _fail("favourites stay")
	# The bag shows the marks.
	game.input_handler.open_tab("hero")
	await process_frame
	await process_frame
	var cell: InventoryItemButton = null
	for node in game.hud.find_children("*", "InventoryItemButton", true, false):
		if node.item_id == "copper_ore":
			cell = node
	if cell == null or not cell._hint.contains("метка"):
		return _fail("the bag cell offers marks")
	cell.mark_requested.emit("copper_ore")
	if hero.item_mark("copper_ore") != "junk":
		return _fail("the wheel click cycles the mark in the bag")
	game.input_handler.toggle_tab("hero")
	# Marks are saved.
	var snapshot: Dictionary = game.make_save_snapshot()
	hero.item_marks.clear()
	game.restore_save_snapshot(snapshot)
	await process_frame
	if hero.item_mark("copper_ore") != "junk":
		return _fail("marks are saved")

	# Where to get it.
	var copper := ItemSources.describe(game, "copper_ore")
	if not copper.contains("медная жила") or not copper.contains("Старая штольня"):
		return _fail("copper comes from the adit: " + copper)
	if not ItemSources.describe(game, "slime_gel").contains("слизень"):
		return _fail("gel drops from slimes: " + ItemSources.describe(game, "slime_gel"))
	if not ItemSources.describe(game, "planks").contains("верстак"):
		return _fail("planks are made at the bench: " + ItemSources.describe(game, "planks"))
	if not ItemSources.describe(game, "wheat").contains("огород"):
		return _fail("wheat grows in the garden: " + ItemSources.describe(game, "wheat"))
	if ItemSources.describe(game, "egg").is_empty() or not ItemSources.describe(game, "no_such_item").is_empty():
		return _fail("special and unknown items")
	# Every ingredient of every recipe has a known source.
	var orphans: Array[String] = []
	for recipe_id in game.crafting_service.recipes:
		for ingredient in game.crafting_service.recipes[recipe_id].get("ingredients", []):
			var item_id := str(ingredient.get("item_id", ""))
			if ItemSources.list(game, item_id).is_empty() and not orphans.has(item_id):
				orphans.append(item_id)
	if not orphans.is_empty():
		return _fail("ingredients without a known source: %s" % str(orphans))

	# The crafting window: hints and a pin.
	hero.inventory.erase("planks")
	hero.inventory.erase("copper_ore")
	game.crafting.open("carpentry")
	await process_frame
	var window := game.hud.crafting_view
	window.selected = "carp_pickaxe"
	window._show_detail()
	var hints := ""
	for node in window.needs_box.get_children():
		if node is Label:
			hints += (node as Label).text
	if not hints.contains("↳") or not hints.contains("медная жила"):
		return _fail("the window says where to get the missing: " + hints)
	if window.pin_button.text != "Закрепить":
		return _fail("the pin button")
	window.toggle_pin()
	if not game.pin.is_pinned("recipe", "carp_pickaxe") or window.pin_button.text != "Открепить":
		return _fail("the recipe is pinned")
	game.crafting.close()
	var rows := _titles(game)
	if not rows.contains("Медная кирка: медная руда 0/4") or not rows.contains("доски 0/2"):
		return _fail("the tracker lists what is missing: " + rows)
	hero.add_item("copper_ore", 4)
	hero.add_item("planks", 2)
	hero.gold += 100
	if not _titles(game).contains("всё собрано"):
		return _fail("the tracker says when all is gathered: " + _titles(game))
	await process_frame
	await process_frame
	snapshot = game.make_save_snapshot()
	game.pin.clear()
	game.restore_save_snapshot(snapshot)
	if not game.pin.is_pinned("recipe", "carp_pickaxe"):
		return _fail("the pin is saved")

	# A building short of materials pins itself.
	hero.gold = 9999
	hero.inventory.erase("wood")
	if game.settlement.upgrade("mill"):
		return _fail("no wood — no mill")
	if not game.pin.is_pinned("building", "mill") or not _titles(game).contains("Водяная мельница: "):
		return _fail("the mill is pinned by itself: " + _titles(game))
	hero.add_item("wood", 10)
	hero.add_item("stone", 8)
	if not game.settlement.upgrade("mill"):
		return _fail("the mill is built")
	if not _titles(game).is_empty() or not game.pin.kind.is_empty():
		return _fail("a built goal leaves the screen")
	print("BAG COMFORTS OK")
	quit(0)
