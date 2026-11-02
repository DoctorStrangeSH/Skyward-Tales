extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(condition: bool, description: String) -> bool:
	if not condition:
		push_error("UNEQUIP TEST FAILED: " + description)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player
	hero.add_item("mana_amulet")
	if not _verify(hero.equip_item("mana_amulet") and hero.max_mana == 80, "amulet equip"):
		return
	hero.mana = 77
	if not _verify(hero.unequip_slot("amulet") and hero.max_mana == 60 and hero.mana == 60, "amulet remove and clamp"):
		return
	if not _verify(int(hero.inventory.get("mana_amulet", 0)) == 1, "returned item"):
		return
	for i in 3:
		if not _verify(hero.equip_item("mana_amulet") and hero.max_mana == 80, "repeat equip"):
			return
		if not _verify(hero.unequip_slot("amulet") and hero.max_mana == 60, "repeat remove"):
			return
	hero.add_item("apprentice_staff")
	hero.add_item("leather_armor")
	hero.equip_item("apprentice_staff")
	hero.equip_item("leather_armor")
	if not _verify(game.hud.inventory_list != null, "inventory not ready"):
		return
	game.hud.toggle_inventory(hero)
	if not _verify(game.hud.equipment_list.get_child_count() == 4, "equipment slots missing"):
		return
	game._on_inventory_unequip("weapon")
	if not _verify(hero.get_spell_bonus() == 0 and int(hero.inventory.get("apprentice_staff", 0)) == 1, "staff unequip"):
		return
	game._on_inventory_unequip("armor")
	if not _verify(hero.get_armor() == 0, "armor unequip"):
		return
	hero.add_item("pyromancer_core")
	if not _verify(hero.equip_item("pyromancer_core") and hero.get_burn_damage_bonus() == 1, "relic equip"):
		return
	if not _verify(hero.unequip_slot("relic") and hero.get_burn_damage_bonus() == 0 and int(hero.inventory.get("pyromancer_core", 0)) == 1, "relic unequip"):
		return
	print("UNEQUIP TEST OK: repeat amulet, max mana clamp, weapon/armor/relic slots")
	quit(0)
