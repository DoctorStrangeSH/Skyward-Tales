extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("SAVE TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Invalid snapshots must be rejected before the live game state is touched.
	var original_health: int = game.player.health
	var original_position: Vector2 = game.player.global_position
	var malformed_restore: Dictionary = game.make_save_snapshot()
	malformed_restore["player"]["inventory"] = []
	if not _require(not game.restore_save_snapshot(malformed_restore), "restore accepted an invalid inventory structure"):
		return
	if not _require(game.player.health == original_health and game.player.global_position == original_position, "invalid restore changed live player state"):
		return

	game.save_path = "user://skyward_tales_ci_save.json"
	game.player.add_item("mana_amulet")
	game.player.equip_item("mana_amulet")
	game.player.add_item("storm_eye")
	game.player.equip_item("storm_eye")
	game.player.add_item("health_potion", 3)
	game.player.health = 47
	game.player.mana = 31
	game.player.global_position = Vector2(330, 260)
	game.player.add_gold(77)
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 2)
	game.selected_spell_id = "frostbolt"
	if not _require(game.save_game(), "save failed"):
		return
	var saved: Dictionary = SaveSystem.load_snapshot(game.save_path)
	if not _require(not saved.is_empty(), "save not readable"):
		return
	game.player.health = 1
	game.player.mana = 1
	game.player.inventory.clear()
	game.player.gold = 0
	game.player.equipment["amulet"] = ""
	game.player.max_mana = 60
	game.player.global_position = Vector2(60, 60)
	game.quests.states["moonleaf_gathering"]["progress"] = 0
	if not _require(game.load_game(), "load failed"):
		return
	var hero: PlayerCharacter = game.player
	if not _require(hero.health == 47 and hero.mana == 31 and hero.max_mana == 80, "HP/MP/amulet failed"):
		return
	if not _require(hero.gold == 77 and int(hero.inventory.get("health_potion", 0)) == 3, "items and gold failed"):
		return
	if not _require(hero.equipment.get("amulet", "") == "mana_amulet" and hero.equipment.get("relic", "") == "storm_eye" and hero.get_chain_targets_bonus() == 1, "equipped amulet failed"):
		return
	if not _require(hero.global_position.distance_to(Vector2(330,260)) < 0.01, "position failed"):
		return
	if not _require(int(game.quests.states["moonleaf_gathering"]["progress"]) == 2, "quest progress failed"):
		return
	if not _require(game.selected_spell_id == "frostbolt", "spell selection failed"):
		return

	# The file loader must reject malformed nested world data as well.
	var invalid_path: String = "user://skyward_tales_invalid_ci_save.json"
	var invalid_snapshot: Dictionary = game.make_save_snapshot()
	invalid_snapshot["version"] = SaveSystem.VERSION
	invalid_snapshot["world"]["loot"] = {}
	var invalid_file: FileAccess = FileAccess.open(invalid_path, FileAccess.WRITE)
	if not _require(invalid_file != null, "could not create malformed save fixture"):
		return
	invalid_file.store_string(JSON.stringify(invalid_snapshot))
	invalid_file.close()
	var rejected_snapshot: Dictionary = SaveSystem.load_snapshot(invalid_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	if not _require(rejected_snapshot.is_empty(), "loader accepted malformed nested world data"):
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("SAVE TEST OK: save/load, malformed payload rejection, and state preservation")
	quit(0)
