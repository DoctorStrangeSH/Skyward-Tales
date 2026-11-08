extends SceneTree

## Crystal Caves: locked behind the guardian, bats spawn, echo crystals advance
## Dorn's quest, the lens reward equips, and progress survives save/load.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("CRYSTAL CAVES TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _count(game: Node, kind: Script) -> int:
	var total := 0
	for node in game.get_children():
		if not node.is_queued_for_deletion() and node.get_script() == kind:
			total += 1
	return total

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.quests.states["moonleaf_gathering"]["completed"] = true
	game._set_region("moonlit_grove", Vector2(1150, 560), false)
	game._on_region_travel("crystal_caves", Vector2(90, 440))
	if not _verify(game.current_region == "moonlit_grove", "caves stay sealed while the guardian lives"):
		return
	game.guardian_defeated = true
	game._on_region_travel("crystal_caves", Vector2(90, 440))
	if not _verify(game.current_region == "crystal_caves", "defeating the guardian opens the caves"):
		return
	await process_frame
	if not _verify(_count(game, load("res://scripts/cave_bat.gd")) == 5, "five crystal bats spawn"):
		return
	for node in game.get_children():
		if not _verify(not (node is WorldCollectible and node.item_id == "echo_crystal"), "echo crystals wait for Dorn's quest"):
			return

	game._on_miner_interacted(null)
	if not _verify(bool(game.quests.states["crystal_heart"]["started"]), "Dorn gives the crystal quest"):
		return
	var crystals: Array[WorldCollectible] = []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "echo_crystal":
			crystals.append(node)
	if not _verify(crystals.size() == 4, "four echo crystals appear with the quest"):
		return
	game.hud.close_dialogue()
	for crystal in crystals:
		game._on_herb_interacted(crystal)
	if not _verify(game.quests.is_ready_to_complete("crystal_heart"), "collecting four crystals completes the objective"):
		return
	if not _verify(game.dialogues.marker_for("miner") == "ready", "Dorn shows a ? marker"):
		return
	game._on_miner_interacted(null)
	game.story.skip()
	if not _verify(game.hud.dialogue_choices_container.get_child_count() == 2, "Dorn offers two rewards"):
		return
	game._on_dialogue_choice_selected("miner_reward:lens")
	if not _verify(game.quests.is_completed("crystal_heart") and int(game.player.inventory.get("crystal_lens", 0)) == 1, "lens reward is granted"):
		return
	if not _verify(game.player.equip_item("crystal_lens") and game.player.get_spell_bonus("chain_lightning") >= 3, "lens equips and boosts lightning"):
		return

	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot) and restored.current_region == "crystal_caves", "save/load keeps the player in the caves"):
		return
	if not _verify(restored.quests.is_completed("crystal_heart") and restored.player.equipment["amulet"] == "crystal_lens", "quest and lens survive save/load"):
		return
	print("CRYSTAL CAVES OK: gate, bats, crystals, Dorn's quest, lens, save/load")
	quit(0)
