extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, why: String) -> bool:
	if not ok:
		push_error("LOOT TEST FAILED: " + why)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: PlayerCharacter = game.player
	if not _check(player.inventory.is_empty(), "Inventory must start empty"):
		return
	game._spawn_loot(player.global_position + Vector2(10.0, 0), "health_potion")
	var loot: WorldLoot = null
	for node in game.get_children():
		if node is WorldLoot:
			loot = node
	if not _check(loot != null, "No loot spawned"):
		return
	loot.interact()
	if not _check(int(player.inventory.get("health_potion", 0)) == 1, "Pickup did not add item"):
		return
	if not _check(not player.use_item("health_potion"), "Potion consumed at full health"):
		return
	player.take_damage(50)
	if not _check(player.use_item("health_potion") and player.health == 85, "Health potion failed"):
		return
	if not _check(not player.use_item("health_potion"), "Used potion remained in inventory"):
		return
	player.add_item("mana_potion", 2)
	player.mana = 10
	if not _check(player.use_item("mana_potion") and player.mana == 35, "Mana potion failed"):
		return
	if not _check(int(player.inventory.get("mana_potion", 0)) == 1, "Stack decrement failed"):
		return
	print("LOOT TEST OK: drops, pickup, inventory stack, health and mana potions")
	quit(0)
