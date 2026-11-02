extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chest_script: GDScript = load("res://scripts/treasure_chest.gd")
	if chest_script.roll_bonus(0.10)["rarity"] != "common" or chest_script.roll_bonus(0.70)["rarity"] != "uncommon" or chest_script.roll_bonus(0.99)["rarity"] != "rare":
		push_error("RARITY TEST: reward thresholds")
		quit(1)
		return
	if chest_script.roll_bonus(0.94)["item"] != "starlight_essence" or chest_script.roll_bonus(0.95)["item"] != "pyromancer_core" or chest_script.roll_bonus(0.97)["item"] != "frost_heart" or chest_script.roll_bonus(0.99)["item"] != "storm_eye":
		push_error("RARITY TEST: rare item pool")
		quit(1)
		return
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var chest: TreasureChest = null
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_ruins":
			chest = node
			break
	if chest == null:
		push_error("RARITY TEST: chest missing")
		quit(1)
		return
	chest.rng.seed = 1234
	chest.interact()
	var bonus_count: int = int(game.player.inventory.get("health_potion", 0)) + int(game.player.inventory.get("mana_amulet", 0)) + int(game.player.inventory.get("starlight_essence", 0)) + int(game.player.inventory.get("pyromancer_core", 0)) + int(game.player.inventory.get("frost_heart", 0)) + int(game.player.inventory.get("storm_eye", 0))
	if bonus_count != 3:
		push_error("RARITY TEST: base loot and bonus not delivered")
		quit(1)
		return
	var saved: Dictionary = game.make_save_snapshot()
	if not game.restore_save_snapshot(saved):
		push_error("RARITY TEST: restore failed")
		quit(1)
		return
	var expected_inventory: Dictionary = game.player.inventory.duplicate(true)
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_ruins":
			node.interact()
	if game.player.inventory != expected_inventory:
		push_error("RARITY TEST: bonus duplicated after load")
		quit(1)
		return
	game.player.add_item("starlight_essence")
	var old_max: int = game.player.max_mana
	if not game.player.use_item("starlight_essence") or game.player.max_mana != old_max + 5:
		push_error("RARITY TEST: rare essence effect")
		quit(1)
		return
	saved = game.make_save_snapshot()
	game.player.starlight_essence_used = 0
	if not game.restore_save_snapshot(saved) or game.player.starlight_essence_used != 1:
		push_error("RARITY TEST: rare essence effect not saved")
		quit(1)
		return
	print("RARITY TEST OK: rarity rolls, single reward, permanent essence, save/load")
	quit(0)
