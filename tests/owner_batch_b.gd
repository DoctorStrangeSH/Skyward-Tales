extends SceneTree

## Owner's list, package B (pacing): chapter gates with hints, tracked
## quests, no map pins for quests not yet taken, quest keys never sold,
## the level curve and level-gap toughness, a longer day.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("OWNER BATCH B FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var quests := game.quests

	# №7: after the moonleaf the elder waits for a good deed in the Reaches.
	quests.states["main_prologue"]["started"] = true
	quests.states["main_prologue"]["completed"] = true
	quests.states["moonleaf_gathering"]["started"] = true
	quests.states["moonleaf_gathering"]["completed"] = true
	var links := game.director.pending_links()
	if links.size() != 1 or str(links[0]["start"]) != "main_star_map":
		return _fail("the star map waits for the elder: %s mode=%s" % [str(links.map(func(l: Dictionary) -> String: return str(l["start"]))), game.director.story_mode()])
	if game.director.link_ready(links[0]):
		return _fail("the star map is closed until a side quest is done")
	if game.director.chapter_marker("elder") != "":
		return _fail("no '!' over the elder while the chapter is closed")
	var hint := game.director.tracker_entries()
	if hint.is_empty() or not str(hint[0]["title"]).contains("Сюжет закрыт"):
		return _fail("the tracker says the story is closed")
	if not game.director.try_talk("elder") or not game.hud.dialogue_label.text.contains("Мира"):
		return _fail("the elder says where to find work (Mira's pages): " + game.hud.dialogue_label.text)
	game.hud.close_dialogue()
	quests.states["toren_wolf_hunt"]["started"] = true
	quests.states["toren_wolf_hunt"]["completed"] = true
	if not game.director.link_ready(links[0]) or game.director.chapter_marker("elder") != "quest":
		return _fail("one good deed opens the chapter")
	game.director.try_talk("elder")
	for i in 600:
		if not game.story.active:
			break
		game.story.skip()
		await process_frame
	if not quests.is_active("main_star_map"):
		return _fail("the elder opens the star map chapter")

	# A gate whose NPC starts the chapter himself: Dorn waits for level 6.
	for id in ["main_star_map", "grove_spirits", "main_guardian"]:
		quests.states[id]["started"] = true
		quests.states[id]["completed"] = true
	quests.active_quest_id = ""
	game._on_miner_interacted(null)
	game.hud.close_dialogue()
	if quests.is_active("crystal_heart"):
		return _fail("Dorn waits for a stronger hero")
	hero.level = 6
	quests.states["farm_slimes"]["started"] = true
	quests.states["farm_slimes"]["completed"] = true
	game._on_miner_interacted(null)
	game.hud.close_dialogue()
	if not quests.is_active("crystal_heart"):
		return _fail("Dorn gives the crystal chapter once it is open")
	hero.level = 1
	quests.states["farm_slimes"]["started"] = false
	quests.states["farm_slimes"]["completed"] = false

	# Later gates also ask for a level.
	for link in game.director.chain:
		if str(link.get("start", "")) == "main_spires" and game.director.link_ready(link):
			return _fail("the spires are not open to a fresh hero")

	# №13: a quest switched off leaves the tracker and the map.
	quests.start_quest("farm_slimes")
	game.quest_nav.refresh()
	var pinned := func() -> bool:
		return game.quest_nav.targets.any(func(t: Dictionary) -> bool: return str(t["title"]) == "Слизь в капусте")
	if not pinned.call():
		return _fail("a tracked quest is on the map")
	quests.set_tracked("farm_slimes", false)
	game.quest_nav.refresh()
	if pinned.call():
		return _fail("an untracked quest leaves the map")
	game.hud.quest_tracker.refresh(quests)
	if game.hud.quest_tracker.entries.any(func(e: Dictionary) -> bool: return str(e.get("id", "")) == "farm_slimes"):
		return _fail("an untracked quest leaves the tracker")
	quests.set_tracked("farm_slimes", true)

	# №14: a side quest nobody has offered yet has no pin.
	game.quest_nav.refresh()
	for target in game.quest_nav.targets:
		if target["kind"] == "offer" and not bool(target.get("main", false)):
			return _fail("an untaken side quest is pinned: " + str(target["title"]))

	# №17: quest keys stay in the bag and are never sold.
	hero.add_item("forge_key", 1)
	if not hero.is_quest_item("forge_key"):
		return _fail("the forge key is a quest item")
	if game.merchant_shop.get_sell_offers(hero).any(func(o: Dictionary) -> bool: return o["id"] == "forge_key"):
		return _fail("the merchant does not buy quest keys")
	if bool(game.merchant_shop.sell(hero, "forge_key").get("success", true)) or int(hero.inventory.get("forge_key", 0)) != 1:
		return _fail("a quest key can't be sold")

	# №27/32: a slower curve, tougher monsters above the hero's level.
	if PlayerCharacter.xp_for_level(1) != 60 or PlayerCharacter.xp_for_level(10) <= 900:
		return _fail("the level curve is steeper: %d" % PlayerCharacter.xp_for_level(10))
	if SkywardGame.gap_xp_mult(0) != 1.0 or SkywardGame.gap_xp_mult(-8) >= 0.5:
		return _fail("low lands give little experience to a strong hero")
	if int(RegionCatalog.get_region("sky_rift").get("level", 0)) < 12:
		return _fail("the late lands have higher levels")

	# №9: a longer day.
	if DayNight.CYCLE < 1500.0:
		return _fail("the day lasts longer")

	print("OWNER BATCH B OK")
	quit(0)
