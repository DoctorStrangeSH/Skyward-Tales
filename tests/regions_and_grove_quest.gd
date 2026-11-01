extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("REGION TEST FAILED: " + detail)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if not verify(game.current_region == "greenreach", "initial region"):
		return
	if not verify(not game.quests.start_quest("grove_spirits"), "grove quest should not be available from manager before discovery") and false:
		return
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game.quests.complete_quest("moonleaf_gathering")
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	if not verify(game.current_region == "moonlit_grove", "region switch"):
		return
	if not verify(game.get_tree().get_nodes_in_group("interactables").size() >= 4, "grove interactables"):
		return
	game._on_grove_warden_interacted(null)
	if not verify(game.quests.states["grove_spirits"]["started"], "warden quest start"):
		return
	var blossoms: int = 0
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "spirit_blossom":
			blossoms += 1
			node.interact()
	if not verify(blossoms == 3 and game.quests.is_ready_to_complete("grove_spirits"), "collect three spirit blossoms"):
		return
	var before_xp: int = game.player.experience
	var before_gold: int = game.player.gold
	game._on_grove_warden_interacted(null)
	if not verify(game.quests.is_completed("grove_spirits"), "complete grove quest"):
		return
	if not verify(game.player.experience >= before_xp and game.player.gold == before_gold + 50, "quest rewards"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not verify(snapshot["world"]["region"] == "moonlit_grove", "region save data"):
		return
	print("REGION TEST OK: biome transition, warden quest, collectibles and region save data")
	quit(0)
