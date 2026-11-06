extends SceneTree

## Тихая Гавань: a peaceful island town (no monsters or raids), its villagers
## and their small quests, walkers, and the lore stones of the Chronicle.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("HAVEN TEST FAILED: " + reason)
	quit(1)

func _npc(game: SkywardGame, npc_id: String) -> WorldNpc:
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == npc_id and not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.day_night.paused = true

	# The bridge from the Green Reaches.
	if RegionCatalog.gate("greenreach", "haven").is_empty() or RegionCatalog.gate("haven", "greenreach").is_empty():
		return _fail("a bridge links the Haven and the Green Reaches")
	game._set_region("haven", Vector2(800, 680), false)
	await process_frame
	if not RegionCatalog.is_peaceful("haven") or RegionCatalog.is_peaceful("greenreach"):
		return _fail("the Haven is peaceful")
	for node in game.get_children():
		if node is SlimeEnemy:
			return _fail("no monsters in the Haven")
	if game.events.can_happen() or game.legends.try_spawn() != null:
		return _fail("no raids or legends in the Haven")

	# Villagers, some of them strolling.
	for npc_id in ["haven_warden", "haven_baker", "haven_gardener", "haven_child", "haven_bard", "haven_anchor", "haven_fisher", "haven_storyteller"]:
		if _npc(game, npc_id) == null:
			return _fail("villager missing: " + npc_id)
	var fisher := _npc(game, "haven_fisher")
	if fisher.look_id != "settler_fisher":
		return _fail("villagers can borrow a look")
	var child := _npc(game, "haven_child")
	var walker: NpcWander = null
	for node in child.get_children():
		if node is NpcWander:
			walker = node
	if walker == null:
		return _fail("Tisha wanders around")
	walker._wait = 0.0
	walker._process(0.1)
	if not child.is_walking():
		return _fail("walkers start walking")

	# A villager quest: the warden's letters.
	if game.dialogues.marker_for("haven_warden") != "quest" or game.dialogues.marker_style("haven_warden", "quest") != "quest":
		return _fail("the warden offers a side quest (blue)")
	game.givers.talk("haven_warden")
	game.dialogues.handle_choice("giver_accept:haven_letters")
	await process_frame
	game._set_region("haven", Vector2(800, 680), false)
	await process_frame
	var letters: Array = []
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == "lost_letter":
			letters.append(node)
	if letters.size() != 4 or (letters[0] as WorldCollectible).art_name() != "lost_letter":
		return _fail("four letters with their own art: %d" % letters.size())
	game.pickups.handle(letters[0])
	if not game.hud.message_label.text.contains("Письмо"):
		return _fail("pickup flavour line")
	for letter in letters.slice(1):
		game.pickups.handle(letter)
	var gold := game.player.gold
	game.givers.talk("haven_warden")
	if not game.quests.is_completed("haven_letters") or game.player.gold <= gold:
		return _fail("letters returned, reward paid")
	if game.achievements.progress("haven_friend") != 1:
		return _fail("Haven achievement counts helped villagers")
	game.hud.close_dialogue()

	# Lore stones and the Chronicle.
	var stone: LoreStone = null
	for node in game.get_children():
		if node is LoreStone and node.lore_id == "haven_founding":
			stone = node
	if stone == null or not stone.fresh or game._interaction_prompt(stone) != "E — прочитать руны":
		return _fail("a fresh lore stone by the bridge")
	var xp := game.player.experience
	stone.interact()
	if not game.hud.dialogue_visible or stone.fresh or not game.lore.read.has("haven_founding") or game.player.experience <= xp:
		return _fail("reading a stone: text, Chronicle, experience")
	game.hud.close_dialogue()
	stone.interact()
	game.hud.close_dialogue()
	if game.lore.read.size() != 1:
		return _fail("a stone counts once")
	game.hud.toggle_journal(game.quests, game.player)
	game.hud.journal_view.show_tab("lore")
	game.hud.journal_view.populate(game.quests, game.player)
	if game.hud.journal_view.detail_box.get_child_count() == 0:
		return _fail("the Chronicle tab")
	game.hud.close_top_window()
	for region_id in ["greenreach", "moonlit_grove", "salt_coast", "misty_marsh", "stone_pass", "wind_spires", "ashen_waste", "sky_island"]:
		if (RegionCatalog.get_region(region_id).get("lore", []) as Array).is_empty():
			return _fail("lore stones across the world: " + region_id)
	var snapshot := game.lore.make_snapshot()
	game.lore.read.clear()
	game.lore.restore_snapshot(snapshot)
	if not game.lore.read.has("haven_founding"):
		return _fail("the Chronicle is saved")
	print("HAVEN OK: peaceful island, villagers, walkers, letters quest, lore stones, Chronicle")
	quit(0)
