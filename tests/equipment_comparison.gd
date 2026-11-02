extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("EQUIPMENT COMPARISON TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _find_stat(comparison: Dictionary, label: String) -> Dictionary:
	for stat in comparison.get("stats", []):
		if str(stat.get("label", "")) == label:
			return stat
	return {}

func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.001

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hero: PlayerCharacter = game.player

	hero.add_item("apprentice_staff")
	if not _require(hero.equip_item("apprentice_staff"), "could not equip baseline staff"):
		return
	hero.equipment_definitions["test_master_staff"] = {
		"name": "Посох архимага",
		"description": "+7 ко всем заклинаниям и ещё +2 к огненному шару",
		"slot": "weapon",
		"rarity": "rare",
		"spell_bonus": {"*": 7, "fireball": 2}
	}
	hero.add_item("test_master_staff")
	var weapon_comparison: Dictionary = hero.get_equipment_comparison("test_master_staff")
	var fire_stat: Dictionary = _find_stat(weapon_comparison, "Огненный шар")
	var frost_stat: Dictionary = _find_stat(weapon_comparison, "Ледяная стрела")
	if not _require(not fire_stat.is_empty() and _near(float(fire_stat.get("before", 0)), 5.0) and _near(float(fire_stat.get("after", 0)), 9.0) and _near(float(fire_stat.get("delta", 0)), 4.0), "wildcard and school-specific spell bonuses were not compared"):
		return
	if not _require(not frost_stat.is_empty() and _near(float(frost_stat.get("before", 0)), 5.0) and _near(float(frost_stat.get("after", 0)), 7.0), "wildcard bonus was not reflected in other spells"):
		return

	hero.add_item("leather_armor")
	if not _require(hero.equip_item("leather_armor"), "could not equip baseline armor"):
		return
	hero.equipment_definitions["test_plate_armor"] = {
		"name": "Пластинчатая броня",
		"description": "+7 к броне",
		"slot": "armor",
		"rarity": "rare",
		"armor": 7
	}
	hero.add_item("test_plate_armor")
	var armor_stat: Dictionary = _find_stat(hero.get_equipment_comparison("test_plate_armor"), "Броня")
	if not _require(not armor_stat.is_empty() and _near(float(armor_stat.get("before", 0)), 4.0) and _near(float(armor_stat.get("after", 0)), 7.0) and _near(float(armor_stat.get("delta", 0)), 3.0), "armor delta was calculated incorrectly"):
		return

	hero.add_item("mana_amulet")
	if not _require(hero.equip_item("mana_amulet"), "could not equip baseline amulet"):
		return
	hero.equipment_definitions["test_greater_amulet"] = {
		"name": "Большой амулет маны",
		"description": "+30 к максимальной мане",
		"slot": "amulet",
		"rarity": "rare",
		"max_mana": 30
	}
	hero.add_item("test_greater_amulet")
	var mana_stat: Dictionary = _find_stat(hero.get_equipment_comparison("test_greater_amulet"), "Максимум маны")
	if not _require(not mana_stat.is_empty() and _near(float(mana_stat.get("before", 0)), 80.0) and _near(float(mana_stat.get("after", 0)), 90.0), "max mana comparison did not preserve non-equipment bonuses"):
		return

	hero.add_item("pyromancer_core")
	if not _require(hero.equip_item("pyromancer_core"), "could not equip baseline relic"):
		return
	hero.add_item("frost_heart")
	var relic_comparison: Dictionary = hero.get_equipment_comparison("frost_heart")
	var fire_relic_stat: Dictionary = _find_stat(relic_comparison, "Огненный шар")
	var frost_relic_stat: Dictionary = _find_stat(relic_comparison, "Ледяная стрела")
	var burn_stat: Dictionary = _find_stat(relic_comparison, "Урон горения")
	var slow_stat: Dictionary = _find_stat(relic_comparison, "Длительность замедления")
	if not _require(not fire_relic_stat.is_empty() and _near(float(fire_relic_stat.get("delta", 0)), -4.0), "relic comparison did not show lost fire damage"):
		return
	if not _require(not frost_relic_stat.is_empty() and _near(float(frost_relic_stat.get("delta", 0)), 4.0), "relic comparison did not show gained frost damage"):
		return
	if not _require(not burn_stat.is_empty() and _near(float(burn_stat.get("before", 0)), 1.0) and _near(float(burn_stat.get("after", 0)), 0.0), "relic comparison omitted burn effect"):
		return
	if not _require(not slow_stat.is_empty() and _near(float(slow_stat.get("before", 0)), 0.0) and _near(float(slow_stat.get("after", 0)), 0.75), "relic comparison omitted slow duration"):
		return

	var hud: GameHud = game.hud
	hud._show_equipment_comparison(hero, "frost_heart")
	if not _require(hud.comparison_panel.visible, "hover comparison panel did not become visible"):
		return
	var grid_text: String = ""
	for child in hud.comparison_grid.get_children():
		if child is Label:
			grid_text += child.text + " "
	if not _require(grid_text.contains("Огненный шар") and grid_text.contains("Длительность замедления") and grid_text.contains("-4") and grid_text.contains("+4"), "comparison panel omitted stat names or signed deltas"):
		return
	hud.toggle_inventory(hero)
	if not _require(not hud.comparison_panel.visible, "comparison panel remained visible after inventory closed"):
		return

	print("EQUIPMENT COMPARISON TEST OK: weapon, armor, mana, relic effects and side panel")
	quit(0)
