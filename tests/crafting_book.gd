extends SceneTree

## Этап 24: the recipe book, recipes at the merchant, crafting orders.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CRAFTING BOOK FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	# Recipes for sale; a known one is not offered again.
	var offers := game.merchant_shop.get_offers(0, 60, hero).map(func(o: Dictionary) -> String: return str(o["id"]))
	if not offers.has("recipe_power_elixir") or not offers.has("recipe_steel_mail"):
		return _fail("Bran sells recipes")
	hero.learned_recipes["recipe_power_elixir"] = true
	offers = game.merchant_shop.get_offers(0, 60, hero).map(func(o: Dictionary) -> String: return str(o["id"]))
	if offers.has("recipe_power_elixir"):
		return _fail("a known recipe is not sold again")
	# The book: every recipe, the unknown ones say where to make and how to learn.
	game.crafting.open("hand")
	await process_frame
	var window := game.hud.crafting_view
	window.category = "book"
	window._rebuild_list()
	if window.rows.size() != game.crafting_service.recipes.size():
		return _fail("the book lists every recipe (%d of %d)" % [window.rows.size(), game.crafting_service.recipes.size()])
	window.selected = "forge_steel_mail"
	window._show_detail()
	if not window.detail_text.text.contains("Не изучен") or not window.detail_text.text.contains("Бран"):
		return _fail("an unknown recipe: how to learn: " + window.detail_text.text)
	if not window.make_button.disabled:
		return _fail("not made away from its station")
	game.crafting.close()
	# Orders: none before the hero settles in, then one a day per master.
	if not game.craft_orders.order("blacksmith").is_empty():
		return _fail("no orders before the prologue")
	game.quests.states["main_prologue"] = {"started": true, "completed": true, "progress": 1}
	while hero.level < 3:
		hero.add_experience(hero.experience_to_next)
	var order := game.craft_orders.order("alchemist")
	if order.is_empty() or not game.craft_orders.summary().contains("Лира"):
		return _fail("Lira's order of the day")
	var business := str(game.dialogues._base_marker("alchemist"))
	if business in ["", "service"]:
		if not game.craft_orders.talk("alchemist") or game.craft_orders.talk("alchemist"):
			return _fail("the order is told once a day")
	elif game.craft_orders.talk("alchemist"):
		return _fail("Lira's quest business comes first (%s)" % business)
	game.hud.close_dialogue()
	hero.add_item(str(order["item"]), int(order["amount"]))
	if game.craft_orders.marker("alchemist") != "ready":
		return _fail("a marker with the goods in the bag")
	var gold := hero.gold
	for day in 3:
		var today := game.craft_orders.order("alchemist")
		hero.add_item(str(today["item"]), int(today["amount"]))
		if not game.craft_orders.deliver("alchemist"):
			return _fail("delivered on day %d" % day)
		game.hud.close_dialogue()
		game.day_night.day += 1
	if hero.gold <= gold or not hero.learned_recipes.has("recipe_swift_tonic"):
		return _fail("paid, and the third order brings a scroll not yet known")
	var snapshot := game.make_save_snapshot()
	game.craft_orders.done.clear()
	if not game.restore_save_snapshot(snapshot) or int(game.craft_orders.done.get("alchemist", 0)) != 3:
		return _fail("orders survive a save")
	print("CRAFTING BOOK OK")
	quit()
