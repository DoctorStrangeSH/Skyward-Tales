extends SceneTree

## Этап 22: peaceful trades pay with rewards of their own.
##  1. Fishing → trail rations: a long buff that survives one lethal blow.
##  2. The mine → fittings for gear: set into the worn piece, replaced by a
##     new one, kept through forging and a save.
##  3. Forestry → furniture for the house (the carved bed doubles the rest)
##     and a tarred hull for the ship (lightning hits half as hard).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("ACTIVITY REWARDS FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()

	# 1. The ration is cooked of fish and bread and saves from one lethal blow.
	hero.add_item("fish", 2)
	hero.add_item("bread", 1)
	var cooked: Dictionary = game.crafting_service.craft(hero, "cook_trail_ration")
	if not bool(cooked.get("success", false)) or int(hero.inventory.get("trail_ration", 0)) != 1:
		return _fail("the ration is cooked of two fish and bread")
	if not hero.use_item("trail_ration") or not hero.buffs.has("ration"):
		return _fail("eating the ration gives the buff")
	if float(hero.buffs["ration"]["time"]) < 890.0:
		return _fail("the ration lasts fifteen minutes")
	hero.health = 10
	hero.take_damage(9999)
	if hero.health != maxi(1, int(hero.max_health * 0.3)) or hero.buffs.has("ration"):
		return _fail("a lethal blow leaves 30%% health and spends the ration: %d" % hero.health)
	hero.add_item("captain_ration", 1)
	hero.use_item("captain_ration")
	hero.take_damage(9999)
	if hero.health != maxi(1, int(hero.max_health * 0.5)):
		return _fail("the captain's ration leaves half: %d" % hero.health)
	hero.health = hero.max_health

	# 2. Fittings. Nothing worn in the slot → the fitting stays in the bag.
	hero.unequip_slot("armor")
	hero.add_item("copper_rivets", 1)
	if hero.use_item("copper_rivets") or int(hero.inventory.get("copper_rivets", 0)) != 1:
		return _fail("rivets need a worn armour")
	hero.add_item("wolfskin_mantle", 1)
	hero.equip_item("wolfskin_mantle")
	var armor_before := hero.get_armor()
	var health_before := hero.max_health
	if not hero.use_item("copper_rivets"):
		return _fail("rivets go into the worn armour")
	var mantle := str(hero.equipment["armor"])
	if hero.gear_mod(mantle) != "copper_rivets" or hero.get_armor() != armor_before + 2 or hero.max_health != health_before + 10:
		return _fail("rivets: +2 armour, +10 health (%d → %d, %d → %d)" % [armor_before, hero.get_armor(), health_before, hero.max_health])
	if int(hero.inventory.get("wolfskin_mantle", 0)) != 0 or not hero.wears_base("wolfskin_mantle"):
		return _fail("the fitted piece replaces the plain one")
	# The same fitting twice is refused.
	hero.add_item("copper_rivets", 1)
	if hero.use_item("copper_rivets"):
		return _fail("the same fitting is not set twice")
	# A weapon: the inset, then the edge replaces it.
	hero.add_item("iron_sword", 1)
	hero.equip_item("iron_sword")
	var mana_before := hero.max_mana
	var crit_before := hero.get_crit_chance()
	hero.add_item("amethyst_inset", 1)
	hero.add_item("facet_edge", 1)
	if not hero.use_item("amethyst_inset") or hero.max_mana != mana_before + 10:
		return _fail("the inset adds mana")
	if not hero.use_item("facet_edge"):
		return _fail("the edge replaces the inset")
	var blade := str(hero.equipment["blade"])
	if hero.max_mana != mana_before or absf(hero.get_crit_chance() - crit_before - 0.04) > 0.001:
		return _fail("the old fitting is gone, the new one counts: mana %d, crit %.3f" % [hero.max_mana, hero.get_crit_chance() - crit_before])
	if int(hero.get_item_definition(blade).get("melee", 0)) != 8 or not str(hero.get_item_name(blade)).ends_with("◆"):
		return _fail("the blade keeps its damage and gets the mark: %s" % hero.get_item_name(blade))
	# Forging keeps the fitting.
	hero.gold = 5000
	hero.add_item("iron_ore", 20)
	var forged := hero.upgrade_item(blade)
	if forged.is_empty() or hero.gear_mod(forged) != "facet_edge" or int(hero.get_item_definition(forged).get("crit", 0)) != 4:
		return _fail("a forged blade keeps the fitting")
	if not str(hero.get_item_name(forged)).contains("+1") or absf(hero.get_crit_chance() - crit_before - 0.04) > 0.001:
		return _fail("forged name and crit: %s" % hero.get_item_name(forged))
	# Recipes of the fittings use what the adit gives.
	for recipe_id in ["forge_amethyst_inset", "forge_facet_edge", "forge_copper_rivets"]:
		if not game.crafting_service.recipes.has(recipe_id):
			return _fail("recipe %s" % recipe_id)

	# 3. Furniture needs a forester's rank and planks.
	var home := game.home
	hero.add_item("planks", 30)
	hero.add_item("resin", 10)
	hero.add_item("copper_ore", 3)
	if home.build_furniture("bed") or home.furniture_blocked("bed").find("ранг") < 0:
		return _fail("the carved bed needs a rank")
	game.forestry.points = 30
	if not home.build_furniture("bed") or int(hero.inventory.get("planks", 0)) != 24:
		return _fail("the bed is built of six planks")
	if not home.build_furniture("bench") or home.build_furniture("bench"):
		return _fail("the bench is built once")
	game.settlement.buildings["home"] = 1
	game.buildings.sleep()
	if float(hero.buffs["power"]["time"]) < 590.0:
		return _fail("the carved bed doubles the rest")
	home.enter()
	await process_frame
	await process_frame
	var benches := 0
	for node in game.get_children():
		if node is TowerObject and node.label == "E — столярный верстак":
			benches += 1
	if benches != 1:
		return _fail("the bench stands in the house: %d" % benches)
	home.open_furnishing()
	if not game.hud.dialogue_visible:
		return _fail("the table opens the furnishing list")
	game.hud.close_dialogue()

	# The hull: rank, planks and resin; lightning halves.
	var ship := game.ship
	game.director.set_flag(SkyShip.READY_FLAG)
	var bolt := ship.storm_damage()
	game.forestry.points = 0
	if ship.upgrade("hull"):
		return _fail("the hull needs a rank")
	game.forestry.points = 30
	if not ship.upgrade("hull") or int(hero.inventory.get("planks", 0)) != 4:
		return _fail("the hull takes twelve planks: %d" % int(hero.inventory.get("planks", 0)))
	if ship.storm_damage() * 2 > bolt + 1:
		return _fail("lightning halves: %d → %d" % [bolt, ship.storm_damage()])

	# A save keeps the fittings and the furniture.
	var snapshot: Dictionary = game.make_save_snapshot()
	home.furniture.clear()
	hero.generated_items.clear()
	if not game.restore_save_snapshot(snapshot):
		return _fail("the save loads")
	await process_frame
	await process_frame
	hero = game.player
	if not home.has_furniture("bed") or not home.has_furniture("bench"):
		return _fail("furniture survives a save")
	if hero.gear_mod(str(hero.equipment["blade"])) != "facet_edge" or hero.gear_mod(str(hero.equipment["armor"])) != "copper_rivets":
		return _fail("fittings survive a save")
	print("ACTIVITY REWARDS OK")
	quit()
