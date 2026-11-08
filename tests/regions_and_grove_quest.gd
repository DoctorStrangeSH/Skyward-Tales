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
	game.set("classic_balance", true)
	root.add_child(game)
	await process_frame
	if not verify(game.current_region == "greenreach", "initial region"):
		return
	game._on_region_travel("moonlit_grove", Vector2(140, 430))
	if not verify(game.current_region == "greenreach", "grove gate lock before first quest"):
		return
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game.quests.complete_quest("moonleaf_gathering")
	game._on_region_travel("moonlit_grove", Vector2(140, 430))
	if not verify(game.current_region == "moonlit_grove", "region switch"):
		return
	if not verify(game.get_tree().get_nodes_in_group("interactables").size() >= 5, "grove interactables"):
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
	var before_gold: int = game.player.gold
	game._on_grove_warden_interacted(null)
	if not verify(game.quests.is_completed("grove_spirits"), "complete grove quest"):
		return
	if not verify(game.player.gold == before_gold + 50, "quest gold reward"):
		return
	if not verify(game.relationships.get_score("ilara") == 20, "Ilara trust reward is applied once"):
		return
	if not verify(game.discovered_landmarks.get("moonlit_grove", {}).has("ilara_ancient_cache"), "Ilara reveals the ancient cache on the map"):
		return
	game._on_grove_warden_interacted(null)
	if not verify(game.hud.dialogue_label.text.contains("древний тайник"), "trusted follow-up dialogue reveals the cache"):
		return
	if not verify(game.relationships.get_score("ilara") == 20, "repeated conversation does not duplicate trust"):
		return
	var wolves: int = 0
	for node in game.get_children():
		if node is ForestWolf:
			wolves += 1
	if not verify(wolves == 5, "five forest wolves spawned"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not verify(snapshot["world"]["region"] == "moonlit_grove", "region save data"):
		return
	print("REGION TEST OK: locked gate, travel, warden quest, blossoms, wolves and save data")
	quit(0)
