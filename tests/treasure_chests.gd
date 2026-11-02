extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var chest: TreasureChest = null
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_ruins":
			chest = node
			break
	if chest == null or chest.is_opened:
		push_error("CHEST TEST: unopened ruins chest missing")
		quit(1)
		return
	var original_gold: int = game.player.gold
	chest.interact()
	if game.player.gold != original_gold + 45 or game.player.inventory.get("health_potion", 0) != 2:
		push_error("CHEST TEST: wrong reward")
		quit(1)
		return
	chest.interact()
	if game.player.gold != original_gold + 45:
		push_error("CHEST TEST: duplicate rewards")
		quit(1)
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not bool(snapshot["world"]["opened_chests"].get("greenreach_ruins", false)):
		push_error("CHEST TEST: opened state not saved")
		quit(1)
		return
	if not game.restore_save_snapshot(snapshot):
		push_error("CHEST TEST: restore failed")
		quit(1)
		return
	var found: bool = false
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_ruins":
			found = node.is_opened and not node.is_in_group("interactables")
	if not found:
		push_error("CHEST TEST: opened chest respawned as lootable")
		quit(1)
		return
	game._set_region("moonlit_grove", Vector2(250, 420), false)
	game._set_region("greenreach", Vector2(130, 210), false)
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_ruins" and not node.is_opened:
			push_error("CHEST TEST: region travel reset chest")
			quit(1)
			return
	print("CHEST TEST OK: rewards once, save/restore, persistent across regions")
	quit(0)
