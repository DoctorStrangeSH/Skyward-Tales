extends SceneTree

## Village growth: meet a settler far away, invite them, build a house at the
## settlement board, the house and its collision appear, the settler lives
## there and serves (discount, meal, potions refreshed by quests); saved.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("SETTLEMENT TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _npc(id: String) -> WorldNpc:
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == id and not node.is_queued_for_deletion():
			return node
	return null

func _objects(kind: String) -> int:
	var total := 0
	for node in game.get_children():
		if node is SettlementObject and node.kind == kind and not node.is_queued_for_deletion():
			total += 1
	return total

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	if not _verify(_objects("board") == 1 and _objects("plot") == 3 and _objects("house") == 0, "the village has a board and three empty plots"):
		return

	# Yarosh waits in the grove.
	game._set_region("moonlit_grove", Vector2(700, 500), false)
	var yarosh := _npc("settler_woodcutter")
	if not _verify(yarosh != null and game.dialogues.marker_for("settler_woodcutter") == "quest", "the woodcutter waits in the grove"):
		return
	yarosh.interacted.emit(yarosh)
	if not _verify(game.hud.dialogue_visible, "he talks about the village"):
		return
	game._on_dialogue_choice_selected("settle_invite:woodcutter")
	await process_frame
	if not _verify(game.settlement.recruited.has("woodcutter") and _npc("settler_woodcutter") == null, "he leaves for the village"):
		return

	# Back home: he waits by the board until a house is built.
	game._set_region("greenreach", Vector2(600, 600), false)
	if not _verify(_npc("settler_woodcutter") != null, "he waits in the village"):
		return
	game.player.gold = 30
	game.settlement.open_board()
	game._on_dialogue_choice_selected("settle_build:woodcutter")
	if not _verify(game.settlement.homes.is_empty(), "not enough gold, nothing built"):
		return
	game.player.gold = 200
	game.player.add_item("wood", 20)
	game.player.add_item("stone", 10)
	game.settlement.open_board()
	game._on_dialogue_choice_selected("settle_build:woodcutter")
	await process_frame
	if not _verify(game.settlement.homes.size() == 1 and game.player.gold == 140, "a house for 60 gold"):
		return
	if not _verify(_objects("house") == 1 and _objects("plot") == 2, "the house replaces a plot"):
		return
	if not _verify(game.settlement.house_cost("cook") == 90 and int(game.settlement.house_materials("cook")["wood"]) == 6, "the woodcutter makes the next house cheaper (gold and wood)"):
		return

	# Martha the cook: a meal after every completed quest.
	game.settlement.invite("cook")
	game.settlement.build("cook")
	game.refresh_settlement()
	if not _verify(game.player.gold == 50, "her house cost 90"):
		return
	game.player.health = 10
	game.settlement.talk("settler_cook")
	if not _verify(game.player.health == game.player.max_health, "the meal restores health"):
		return
	game.hud.close_dialogue()
	game.player.health = 10
	game.settlement.talk("settler_cook")
	if not _verify(game.player.health == 10, "one meal per completed quest"):
		return
	game.hud.close_dialogue()
	game.quests.start_quest("main_prologue")
	game.quests.add_progress("main_prologue", 1)
	game.quests.complete_quest("main_prologue")
	if not _verify(game.dialogues.marker_for("settler_cook") == "ready", "a finished quest earns another meal"):
		return

	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	if not _verify(restored.settlement.homes.size() == 2 and restored.settlement.recruited.has("cook"), "the village is saved"):
		return
	var houses := 0
	for node in restored.get_children():
		if node is SettlementObject and node.kind == "house":
			houses += 1
	if not _verify(houses == 2, "both houses stand after loading"):
		return
	print("SETTLEMENT OK: invite, wait, build, gold, discount, meal per quest, save/load")
	quit(0)
