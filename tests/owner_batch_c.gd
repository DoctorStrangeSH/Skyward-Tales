extends SceneTree

## Owner's list, package C (gear): one- and two-handed weapons, shields with
## block %, rings / earrings / cloaks, the new physical and magic stats,
## legendaries from bosses, item cards, bag reordering, old saves.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("OWNER BATCH C FAILED: " + reason)
	quit(1)

func _texts(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	for child in node.get_children():
		result += _texts(child)
	return result

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player

	# №23–25: a sword and a shield; a two-handed maul pushes the shield off.
	for id in ["iron_sword", "wooden_shield", "mountain_maul", "apprentice_staff", "hunting_bow"]:
		hero.add_item(id)
	hero.equip_item("iron_sword")
	hero.equip_item("wooden_shield")
	if hero.equipment["blade"] != "iron_sword" or hero.equipment["offhand"] != "wooden_shield" or hero.two_handed():
		return _fail("a one-handed sword goes with a shield")
	if not hero.get_equipment_comparison("mountain_maul").get("also_removes", []).has("Деревянный щит"):
		return _fail("the card warns that the maul takes the shield hand")
	hero.equip_item("mountain_maul")
	if hero.equipment["offhand"] != "" or not hero.two_handed() or int(hero.inventory.get("wooden_shield", 0)) != 1:
		return _fail("a two-handed maul sends the shield back to the bag")
	hero.equip_item("wooden_shield")
	if hero.equipment["blade"] != "" or hero.equipment["offhand"] != "wooden_shield":
		return _fail("a shield sends the two-handed weapon back to the bag")
	# Staves and bows are two-handed weapons in the same hand as the sword.
	hero.equip_item("apprentice_staff")
	if hero.equipment["blade"] != "apprentice_staff" or hero.has_shield() or hero.weapon_kind() != "staff":
		return _fail("a staff is held in both hands")
	hero.equip_item("hunting_bow")
	if not hero.has_bow() or hero.weapon_kind() != "bow" or int(hero.inventory.get("apprentice_staff", 0)) != 1:
		return _fail("a bow replaces the staff, never next to it")

	# №25–26: no shield — no block or parry; a shield stops its percent.
	if hero.start_guard():
		return _fail("guarding needs a shield")
	hero.equip_item("iron_sword")
	hero.add_item("iron_shield")
	hero.equip_item("iron_shield")
	if not hero.start_guard() or not is_equal_approx(hero.get_block(), 0.4):
		return _fail("the iron shield blocks 40%")
	hero.parry_left = 0.0
	hero.health = hero.max_health
	var before := hero.health
	hero.take_damage(50)
	var blocked := before - hero.health
	hero.end_guard()
	hero.health = hero.max_health
	hero.take_damage(50)
	var open := hero.max_health - hero.health
	if blocked >= open or blocked > roundi(50 * 0.6):
		return _fail("a raised shield takes 40%% of the blow (%d vs %d)" % [blocked, open])

	# №11: two rings, earrings, a cloak.
	for id in ["copper_ring", "duelist_ring", "ember_ring", "silver_earrings", "travel_cloak"]:
		hero.add_item(id)
	hero.equip_item("copper_ring")
	hero.equip_item("duelist_ring")
	if hero.equipment["ring1"] != "copper_ring" or hero.equipment["ring2"] != "duelist_ring":
		return _fail("rings fill both ring slots")
	hero.equip_item("ember_ring", "ring2")
	if hero.equipment["ring2"] != "ember_ring" or int(hero.inventory.get("duelist_ring", 0)) != 1:
		return _fail("a ring dropped on the second slot replaces that ring")
	hero.equip_item("silver_earrings")
	hero.equip_item("travel_cloak")
	if hero.equipment["earrings"] != "silver_earrings" or hero.equipment["cloak"] != "travel_cloak":
		return _fail("earrings and a cloak have their slots")

	# №3: new stats.
	hero.equip_item("duelist_ring", "ring1")
	if not is_equal_approx(hero.get_crit_multiplier(), 2.2):
		return _fail("the duelist ring adds 20% critical damage")
	if hero.get_spell_power_multiplier("fireball") <= hero.get_spell_power_multiplier("frostbolt"):
		return _fail("the ember ring strengthens fire only")
	if hero.get_resist() != 4:
		return _fail("earrings and cloak give magic defence: %d" % hero.get_resist())
	var orb := EnemyMagicOrb.new()
	game.add_child(orb)
	hero.health = hero.max_health
	hero.take_damage(30, orb)
	var magic_hit := hero.max_health - hero.health
	hero.health = hero.max_health
	hero.take_damage(30)
	var plain_hit := hero.max_health - hero.health
	if magic_hit == plain_hit:
		return _fail("spells meet the magic defence, not the armour (%d / %d)" % [magic_hit, plain_hit])
	orb.queue_free()
	hero.add_item("vigor_ring")
	hero.equip_item("vigor_ring", "ring2")
	hero.health = 10
	hero._hp_regen_clock = 4.99
	hero._physics_process(0.05)
	if hero.health != 13:
		return _fail("the vigor ring heals 3 every 5 seconds: %d" % hero.health)

	# №2, 31: rolled gear of every kind; legendaries from bosses.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var plain_legends := 0
	var boss_legends := 0
	for i in 3000:
		if LootGenerator.roll_rarity(rng) == "legendary":
			plain_legends += 1
		if LootGenerator.roll_rarity(rng, "rare", "boss") == "legendary":
			boss_legends += 1
	if plain_legends > 6 or boss_legends < 300:
		return _fail("legendaries: %d from foes, %d from bosses" % [plain_legends, boss_legends])
	var kinds := {}
	for i in 300:
		var rolled := LootGenerator.generate(rng, 5, "rare")
		kinds[str(rolled.get("slot", ""))] = true
		if rolled.get("slot", "") == "offhand" and int(rolled.get("block", 0)) != 40:
			return _fail("a rolled rare shield blocks 40%")
		if rolled.get("kind", "") in ["staff", "bow"] and (rolled.get("slot", "") != "blade" or int(rolled.get("hands", 1)) != 2):
			return _fail("rolled staves and bows are two-handed weapons")
	for slot in ["blade", "offhand", "armor", "cloak", "amulet", "earrings", "ring", "relic"]:
		if not kinds.has(slot):
			return _fail("loot rolls every kind of piece: " + slot)

	# №1: the item card.
	var card := ItemTooltip.make(hero, "mountain_maul")
	var text := _texts(card)
	if not text.contains("Двуручный молот") or not text.contains("Снимет: Окованный щит") or not text.contains("▲"):
		return _fail("the item card shows type, comparison and what comes off:\n" + text)
	card.free()

	# №22: drag in the bag moves an item before another one, and it stays.
	hero.add_item("health_potion", 2)
	hero.add_item("wood", 3)
	game.hud.toggle_inventory(hero)
	await process_frame
	var view := game.hud.inventory_view
	var cells := func() -> Array:
		var ids: Array = []
		for node in view.item_list.get_children():
			if node is InventoryItemButton:
				ids.append(node.item_id)
		return ids
	view._reorder("wood", str(cells.call()[0]))
	await process_frame
	if str(cells.call()[0]) != "wood":
		return _fail("wood dragged to the front stays there: " + str(cells.call()))
	var snapshot := game.make_save_snapshot()
	game.hud.toggle_inventory(hero)

	# Saves from before the package: the staff lived in its own slot.
	var old: Dictionary = snapshot.duplicate(true)
	old["player"]["equipment"] = {"blade": "iron_sword", "weapon": "apprentice_staff", "armor": "travel_cloak", "amulet": "", "relic": ""}
	old["player"]["inventory"].erase("apprentice_staff")
	old["player"]["inventory"].erase("travel_cloak")
	game.restore_save_snapshot(old)
	if hero.equipment["blade"] != "iron_sword" or int(hero.inventory.get("apprentice_staff", 0)) != 1 or hero.equipment["cloak"] != "travel_cloak":
		return _fail("an old save: the staff goes to the bag, the cloak to its slot: " + str(hero.equipment))
	if hero.bag_order.is_empty() or str(hero.bag_order[0]) != "wood":
		return _fail("the bag order survives save and load")

	# Borin's shop has shelves.
	game.borin.open_shop()
	if game.hud.dialogue_choices_container.get_child_count() < 3:
		return _fail("Borin shows his shelves")
	game.borin.open_shop("armour")
	var shelf := ""
	for button in game.hud.dialogue_choices_container.get_children():
		shelf += (button as Button).text + "\n"
	if not shelf.contains("Окованный щит"):
		return _fail("the iron shield is on Borin's armour shelf:\n" + shelf)
	game.hud.close_dialogue()

	print("OWNER BATCH C OK")
	quit(0)
