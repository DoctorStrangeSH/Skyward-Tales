extends SceneTree

## Quest markers above NPCs follow quest state: ! available, ? ready, * service.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("NPC MARKER TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var d := game.dialogues
	if not _verify(d.marker_for("elder") == "quest", "elder offers the first quest"):
		return
	if not _verify(d.marker_for("cartographer") == "" and d.marker_for("hunter") == "" and d.marker_for("merchant") == "", "side quests locked before helping the elder"):
		return
	game.update_npc_markers()
	if not _verify(game.elder.marker == "quest_main", "marker is applied to the elder node"):
		return

	game.quests.start_quest("moonleaf_gathering")
	if not _verify(d.marker_for("elder") == "", "no marker while the quest is in progress"):
		return
	game.quests.add_progress("moonleaf_gathering", 3)
	if not _verify(d.marker_for("elder") == "ready", "elder shows ? when the quest can be handed in"):
		return
	game._on_dialogue_choice_selected("payment")
	if not _verify(d.marker_for("elder") == "", "elder marker clears after completion"):
		return
	for npc in ["cartographer", "hunter", "merchant"]:
		if not _verify(d.marker_for(npc) == "quest", npc + " offers a quest after the elder is helped"):
			return

	game.quests.start_quest("toren_wolf_hunt")
	# Side quests run side by side (owner's list №12): the others still offer theirs.
	if not _verify(d.marker_for("cartographer") == "quest" and d.marker_for("merchant") == "quest", "side quests run side by side"):
		return
	game.quests.add_progress("toren_wolf_hunt", 3)
	if not _verify(d.marker_for("hunter") == "ready", "hunter shows ? when wolves are done"):
		return

	if not _verify(d.marker_for("blacksmith") == "", "blacksmith idle without materials"):
		return
	game.player.add_item("apprentice_staff")
	game.player.add_item("iron_ore", 3)
	game.player.add_gold(60)
	if not _verify(d.marker_for("blacksmith") == "service", "blacksmith shows a service marker when a recipe is affordable"):
		return
	print("NPC MARKER OK: available, ready, locked, service")
	quit(0)
