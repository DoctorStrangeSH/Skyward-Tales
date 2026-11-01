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
	print("EQUIPMENT TEST OK: gear bonuses, spell damage and duplicate guards")
	quit(0)
