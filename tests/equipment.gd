extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	hero.add_item("apprentice_staff")
	hero.add_item("leather_armor")
	hero.add_item("mana_amulet")
	if not hero.equip_item("apprentice_staff") or hero.get_spell_bonus() != 5:
		push_error("EQUIPMENT TEST FAILED: staff bonus")
		quit(1)
		return
	if not hero.equip_item("leather_armor") or hero.get_armor() != 4:
		push_error("EQUIPMENT TEST FAILED: armor equip")
		quit(1)
		return
	hero.take_damage(10)
	if hero.health != hero.max_health - 6:
		push_error("EQUIPMENT TEST FAILED: armor damage reduction")
		quit(1)
		return
	if not hero.equip_item("mana_amulet") or hero.max_mana != 80:
		push_error("EQUIPMENT TEST FAILED: amulet mana")
		quit(1)
		return
	if hero.equip_item("mana_amulet"):
		push_error("EQUIPMENT TEST FAILED: duplicate equip")
		quit(1)
		return
	game.select_spell("fireball")
	game._cast_spell()
	var bolt: MagicBolt = null
	for node in game.get_children():
		if node is MagicBolt:
			bolt = node
	if bolt == null or bolt.damage != 23:
		push_error("EQUIPMENT TEST FAILED: spell damage bonus")
		quit(1)
		return
	hero.add_item("pyromancer_core")
	if not hero.equip_item("pyromancer_core") or hero.get_spell_bonus("fireball") != 9 or hero.get_burn_damage_bonus() != 1:
		push_error("EQUIPMENT TEST FAILED: pyromancer relic bonuses")
		quit(1)
		return
	game.cast_cooldown_remaining = 0.0
	game._cast_spell()
	bolt = null
	for node in game.get_children():
		if node is MagicBolt:
			bolt = node
	if bolt == null or bolt.damage != 27 or bolt.burn_damage != 4:
		push_error("EQUIPMENT TEST FAILED: pyromancer spell modifiers")
		quit(1)
		return
	hero.add_item("frost_heart")
	if not hero.equip_item("frost_heart") or hero.get_spell_bonus("frostbolt") != 9 or absf(hero.get_slow_duration_bonus() - 0.75) > 0.001:
		push_error("EQUIPMENT TEST FAILED: frost relic bonuses or same-slot replacement")
		quit(1)
		return
	game.select_spell("frostbolt")
	game.cast_cooldown_remaining = 0.0
	game._cast_spell()
	var frost_bolt: MagicBolt = null
	for node in game.get_children():
		if node is MagicBolt and node.spell_id == "frostbolt":
			frost_bolt = node
	if frost_bolt == null or absf(frost_bolt.slow_duration - 3.25) > 0.001:
		push_error("EQUIPMENT TEST FAILED: frost slow duration applied to projectile")
		quit(1)
		return
	if int(hero.inventory.get("pyromancer_core", 0)) != 1:
		push_error("EQUIPMENT TEST FAILED: previous relic not returned")
		quit(1)
		return
	hero.add_item("storm_eye")
	if not hero.equip_item("storm_eye") or hero.get_spell_bonus("chain_lightning") != 9 or hero.get_chain_targets_bonus() != 1:
		push_error("EQUIPMENT TEST FAILED: storm relic bonuses")
		quit(1)
		return
	game.select_spell("chain_lightning")
	game.cast_cooldown_remaining = 0.0
	game._cast_spell()
	var storm_bolt: MagicBolt = null
	for node in game.get_children():
		if node is MagicBolt and node.spell_id == "chain_lightning":
			storm_bolt = node
	if storm_bolt == null or storm_bolt.chain_targets != 3:
		push_error("EQUIPMENT TEST FAILED: storm chain target applied to projectile")
		quit(1)
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not game.restore_save_snapshot(snapshot) or hero.equipment.get("relic", "") != "storm_eye" or hero.get_chain_targets_bonus() != 1:
		push_error("EQUIPMENT TEST FAILED: relic save/load")
		quit(1)
		return
	var old_save: Dictionary = game.make_save_snapshot()
	old_save["player"]["equipment"].erase("relic")
	if not game.restore_save_snapshot(old_save) or hero.equipment.get("relic", "missing") != "":
		push_error("EQUIPMENT TEST FAILED: old save compatibility")
		quit(1)
		return
	print("EQUIPMENT TEST OK: data-driven gear, elemental relics, replacement and persistence")
	quit(0)
