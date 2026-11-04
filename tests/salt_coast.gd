extends SceneTree

## Salt Coast: the west road from the village, keeper Moren's chain (crabs,
## lighthouse oil, Crab King), the lighthouse lights up, the world map knows
## the visited lands.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("SALT COAST TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _all(script_name: String) -> Array:
	var found := []
	for node in game.get_children():
		if not node.is_queued_for_deletion() and node.get_script() != null and node.get_script().get_global_name() == script_name:
			found.append(node)
	return found

func _lighthouse_art() -> String:
	for node in game.get_children():
		if node is SettlementObject and node.has_meta("dynamic") and not node.is_queued_for_deletion():
			return node.art
	return ""

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game._on_region_travel("salt_coast", Vector2(1500, 540))
	await process_frame
	if not _verify(game.current_region == "salt_coast" and game.visited_regions.has("salt_coast"), "the west road leads to the coast"):
		return
	if not _verify(_all("CoastCrab").size() == 6 and _all("CrabKing").is_empty(), "crabs on the beach, the king hides"):
		return
	if not _verify(_lighthouse_art() == "coast_lighthouse", "the lighthouse is dark"):
		return
	game.givers.talk("keeper")
	game._on_dialogue_choice_selected("giver_accept:coast_crabs")
	for crab in _all("CoastCrab").slice(0, 5):
		crab.take_damage(9999)
		await process_frame
	game.givers.talk("keeper")
	game.hud.close_dialogue()
	if not _verify(game.quests.is_completed("coast_crabs"), "five crabs please Moren"):
		return
	game.givers.talk("keeper")
	game._on_dialogue_choice_selected("giver_accept:coast_light")
	var barrels := []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "lamp_oil":
			barrels.append(node)
	if not _verify(barrels.size() == 3, "oil barrels appear with the quest"):
		return
	for barrel in barrels:
		game._on_herb_interacted(barrel)
	game.givers.talk("keeper")
	game.hud.close_dialogue()
	await process_frame
	await process_frame
	if not _verify(game.quests.is_completed("coast_light") and _lighthouse_art() == "coast_lighthouse_lit", "the lighthouse shines again"):
		return
	game.givers.talk("keeper")
	game._on_dialogue_choice_selected("giver_accept:coast_king")
	var kings := _all("CrabKing")
	if not _verify(kings.size() == 1, "the Crab King rises"):
		return
	kings[0].take_damage(9999)
	await process_frame
	game.givers.talk("keeper")
	game.hud.close_dialogue()
	if not _verify(game.quests.is_completed("coast_king") and int(game.player.inventory.get("storm_eye", 0)) >= 1, "the chain ends with a storm eye"):
		return
	game.open_map()
	game.hud.world_map_view.show_world(true)
	if not _verify(game.hud.world_map_view.overview.visited.has("salt_coast") and game.hud.world_map_view.overview.visible, "the world map shows visited lands"):
		return
	print("SALT COAST OK: road, crabs, oil, lit lighthouse, Crab King, world map")
	quit(0)
