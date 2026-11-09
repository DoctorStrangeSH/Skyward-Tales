extends SceneTree

## Этап 17: factions (reputation, errands, rivals, shop, gift, apology),
## the fates of the islands, Mira's personal quest, new companions, the
## hidden Free Port.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("STAGE 17 TEST FAILED: " + reason)
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
	game.events.enabled = false
	var f := game.factions
	var q := game.quests
	var hero := game.player
	hero.add_gold(10000)

	# --- Factions ---------------------------------------------------------
	if f.ids().size() != 3 or f.rank("keepers") != "Нейтралитет":
		return _fail("three neutral factions")
	game._travel("sky_island", Vector2(600, 600))
	await process_frame
	if _npc(game, "order_novice") == null:
		return _fail("Liara waits on the Sky Island")
	game.givers.talk("order_novice")
	if not game.hud.dialogue_visible:
		return _fail("envoy talk")
	game.hud.close_dialogue()
	var errand := f.current_errand("keepers")
	if f.finish_errand("keepers"):
		return _fail("no errand without items")
	for item_id in errand["items"]:
		hero.add_item(str(item_id), int(errand["items"][item_id]))
	if f.marker("order_novice") != "ready":
		return _fail("envoy marker when the errand can be done")
	var gold_before := hero.gold
	game.dialogues.handle_choice("fac_errand:keepers")
	if f.value("keepers") != int(errand["rep"]) or hero.gold <= gold_before:
		return _fail("errand pays reputation and gold")
	if f.value("roots") >= 0:
		return _fail("rivals notice")
	if f.current_errand("keepers")["id"] == errand["id"]:
		return _fail("the next errand rotates")
	game.hud.close_dialogue()
	# Shop from Friends.
	game.dialogues.handle_choice("fac_buy:keepers:order_blade")
	if hero.inventory.has("order_blade"):
		return _fail("no shop before Friends")
	f.rep["keepers"] = 30
	game.dialogues.handle_choice("fac_buy:keepers:order_blade")
	if not hero.inventory.has("order_blade"):
		return _fail("faction shop")
	game.hud.close_dialogue()
	# Gift for allies, once.
	f.add_rep("keepers", 40)
	if f.marker("order_novice") != "ready":
		return _fail("gift marker")
	game.dialogues.handle_choice("fac_gift:keepers")
	game.dialogues.handle_choice("fac_gift:keepers")
	if int(hero.inventory.get("aella_tear", 0)) != 1:
		return _fail("one gift for allies")
	if not game.achievements.done.has("faction_ally"):
		return _fail("ally achievement")
	game.hud.close_dialogue()
	# Apology.
	f.rep["roots"] = -50
	var cost := f.apology_cost("roots")
	gold_before = hero.gold
	game.dialogues.handle_choice("fac_apology:roots")
	if f.value("roots") < -10 or hero.gold != gold_before - cost:
		return _fail("an apology mends relations")
	game.hud.close_dialogue()

	# --- Fates of the islands ------------------------------------------------
	var crystal: IslandCrystal = null
	for node in game.get_children():
		if node is IslandCrystal:
			crystal = node
	if crystal == null:
		return _fail("a support crystal on the Sky Island")
	crystal.interact()
	if q.is_active(IslandFates.QUEST):
		return _fail("fates need Vail's truth first")
	game.hud.close_dialogue()
	q.states["main_vail"]["completed"] = true
	crystal.interact()
	if not q.is_active(IslandFates.QUEST):
		return _fail("the fate quest starts at a crystal")
	var keepers := f.value("keepers")
	game.dialogues.handle_choice("fate_restore")
	if game.fates.fate("sky_island") != "restore" or f.value("keepers") <= keepers or crystal.state != "restore":
		return _fail("restoring the crystal")
	if not is_equal_approx(game.fates.power_mult("sky_island"), 0.85):
		return _fail("a restored island is gentler")
	if game.get_children().filter(func(n: Node) -> bool: return n is WeatherOverlay and n.mode == "bloom").is_empty():
		return _fail("a restored island blooms")
	if game.fates.decide("sky_island", "take"):
		return _fail("a fate is forever")
	game.hud.close_dialogue()
	hero.health = 10
	hero.global_position = crystal.global_position + Vector2(0, 30)
	game.fates._aura_clock = 0.0
	game.fates.tick(0.1)
	if hero.health <= 10:
		return _fail("the restored crystal heals")
	game._travel("wind_spires", Vector2(640, 500))
	await process_frame
	var captains := f.value("captains")
	if not game.fates.decide("wind_spires", "take"):
		return _fail("taking the power")
	if f.value("captains") <= captains or game.fates.power_mult("wind_spires") <= 1.0:
		return _fail("taking pleases captains and angers the island")
	game.hud.close_dialogue()
	game._travel("sky_rift", Vector2(640, 500))
	await process_frame
	if game.fates.decide("sky_rift", "harmony"):
		return _fail("the third way needs the Song")
	q.states["haven_songs"]["completed"] = true
	if not game.fates.decide("sky_rift", "harmony"):
		return _fail("the third way")
	if not q.is_completed(IslandFates.QUEST):
		return _fail("three fates finish the quest")
	game.hud.close_dialogue()

	# --- Mira's quest and the Free Port ------------------------------------------
	game.ensure_companion()
	game.director.set_flag(SkyShip.READY_FLAG)
	if not game.party.can_offer_mira():
		return _fail("Mira asks once the ship flies")
	game._on_cartographer_interacted(game.companion)
	game.dialogues.handle_choice("party_mira_accept")
	if not q.is_active(Party.MIRA_QUEST) or game.party.stage != "raina":
		return _fail("Mira's quest starts")
	f.rep["captains"] = 0
	if game.ship.blocked("free_port") != "координаты неизвестны":
		return _fail("the Free Port is hidden")
	game._travel("salt_coast", Vector2(900, 600))
	await process_frame
	if game.party.marker("captain_raina") != "quest":
		return _fail("Raina marker")
	game.givers.talk("captain_raina")
	if game.party.stage != "port" or not game.ship.blocked("free_port").is_empty():
		return _fail("Raina gives the coordinates")
	game.hud.close_dialogue()
	if not game.ship.fly_now("free_port"):
		return _fail("flight to the Free Port")
	await process_frame
	if not RegionCatalog.is_peaceful("free_port") or _npc(game, "port_captain_vorn") == null:
		return _fail("the Free Port and Vorn")
	game.givers.talk("port_captain_vorn")
	if game.party.stage != "logbook" or not q.is_ready_to_complete(Party.MIRA_QUEST):
		return _fail("Vorn hands over the logbook")
	game.hud.close_dialogue()
	game._on_cartographer_interacted(game.companion)
	if not q.is_completed(Party.MIRA_QUEST) or not hero.inventory.has("mira_compass"):
		return _fail("Mira's quest reward")
	if game.companion.heal_amount != 35:
		return _fail("Mira heals better")
	game.hud.close_dialogue()

	# --- New companions ------------------------------------------------------------
	if game.party.can_recruit("hunter"):
		return _fail("Toren joins only after a legend hunt")
	game.legends.hunts_done = 1
	if not game.party.recruit("hunter"):
		return _fail("Toren joins")
	await process_frame
	var toren := game.party.follower()
	if toren == null or toren.role != "hunter":
		return _fail("Toren follows the hero")
	var slime := game.spawn_enemy("slime", hero.global_position + Vector2(60, 0))
	slime.set_physics_process(false)
	# Companions fight what attacks the hero (owner's list №18).
	slime.brain_state = SlimeEnemy.BrainState.CHASE
	toren.attack_ready_in = 0.0
	await process_frame
	await process_frame
	if game.get_children().filter(func(n: Node) -> bool: return n is Arrow).is_empty():
		return _fail("Toren shoots")
	game._travel("greenreach", Vector2(900, 600))
	await process_frame
	await process_frame
	if _npc(game, "hunter") != null and not _npc(game, "hunter").is_companion:
		return _fail("Toren's camp is empty while he travels")
	if game.party.follower() == null:
		return _fail("the companion survives travel")
	# Raina instead of Toren.
	if not game.party.recruit("captain_raina") or game.party.follower().role != "captain":
		return _fail("Raina joins in Toren's place")
	var snap := game.party.make_snapshot()
	var fac_snap := f.make_snapshot()
	var fate_snap := game.fates.make_snapshot()
	game.party.restore_snapshot({})
	f.restore_snapshot({})
	game.fates.restore_snapshot({})
	game.party.restore_snapshot(snap)
	f.restore_snapshot(fac_snap)
	game.fates.restore_snapshot(fate_snap)
	game.party.ensure_follower()
	await process_frame
	if game.party.extra != "captain_raina" or game.party.follower() == null:
		return _fail("party saved")
	if f.value("keepers") < 60 or game.fates.fate("sky_rift") != "harmony":
		return _fail("factions and fates saved")
	game.party.dismiss()
	if game.party.follower() != null or not game.party.extra.is_empty():
		return _fail("dismiss")
	# The journal tab.
	game.hud.journal_view.tab = "fac"
	game.hud.journal_view.populate(q, hero)
	if game.hud.journal_view.detail_box.get_child_count() < 6:
		return _fail("factions journal tab")
	print("STAGE 17 TEST PASSED")
	quit(0)
