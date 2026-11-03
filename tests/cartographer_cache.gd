extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("CARTOGRAPHER CACHE FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var cache: TreasureChest = null
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_cartographer_cache":
			cache = node
	if not _require(cache != null and not cache.is_opened, "optional cache not spawned"):
		return
	var initial_gold: int = game.player.gold
	var initial_mana_potions: int = int(game.player.inventory.get("mana_potion", 0))
	cache.interact()
	if not _require(game.player.gold == initial_gold + 20 and int(game.player.inventory.get("mana_potion", 0)) >= initial_mana_potions + 2, "cache guaranteed rewards"):
		return
	if not _require(game.hud.message_label.text.contains("картографа"), "narrative discovery message"):
		return
	cache.interact()
	if not _require(game.player.gold == initial_gold + 20, "duplicate reward"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not _require(bool(snapshot["world"]["opened_chests"].get("greenreach_cartographer_cache", false)), "cache state not saved"):
		return
	if not _require(game.restore_save_snapshot(snapshot), "snapshot restore failed"):
		return
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "greenreach_cartographer_cache":
			if not _require(node.is_opened and not node.is_in_group("interactables"), "cache became lootable after restore"):
				return
	print("CARTOGRAPHER CACHE OK: optional discovery, rewards and persistence")
	quit(0)
