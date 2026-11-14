extends SceneTree

## Этап 24: personal stories of Toren and Raina — offered in their talk,
## steps need them beside the hero, a fight, a choice with its own item.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("COMPANION QUESTS FAILED: " + reason)
	quit(1)

func _bring(game: SkywardGame, who: String) -> void:
	game.party.dismiss(false)
	game.party.extra = who
	game.party.ensure_follower()
	await process_frame
	game.party.follower().global_position = game.player.global_position + Vector2(24, 0)

func _go(game: SkywardGame, region: String, at: Vector2) -> void:
	game._set_region(region, at, false)
	for i in 14:
		await physics_frame
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	await process_frame

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	var cq := game.companion_quests
	if cq.available("toren_trail"):
		return _fail("not before Toren trusts the hero")
	while hero.level < 9:
		hero.add_experience(hero.experience_to_next)
	game.crew.state("hunter")["level"] = 3
	game.crew.state("captain_raina")["level"] = 3
	if cq.offer_choice("hunter").is_empty():
		return _fail("Toren offers his story")
	game.dialogues.handle_choice("cq_start:toren_trail")
	game.dialogues.handle_choice("cq_accept:toren_trail")
	if not game.quests.is_active("toren_trail"):
		return _fail("the story starts")
	await _go(game, "moonlit_grove", Vector2(580, 420))
	var map := game.world.get_world_2d().navigation_map
	for step in cq.info("toren_trail")["steps"]:
		var at := SkywardGame._vec(step["position"])
		if NavigationServer2D.map_get_closest_point(map, at).distance_to(at) > 24.0:
			return _fail("a place one can walk to: %s" % str(at))
	if get_nodes_in_group("cq_spot").size() != 1:
		return _fail("the first place is marked")
	# Alone: Toren must be beside the hero.
	if cq.look("toren_trail"):
		return _fail("without Toren nothing happens")
	await _bring(game, "hunter")
	if not cq.look("toren_trail") or int(cq.steps["toren_trail"]) != 1:
		return _fail("the old track")
	game.hud.close_dialogue()
	cq.look("toren_trail")
	game.hud.close_dialogue()
	# The fight: foes rise when the hero comes near.
	hero.global_position = SkywardGame._vec(cq.current("toren_trail")["position"])
	game.party.follower().global_position = hero.global_position + Vector2(20, 0)
	cq._process(0.1)
	if cq._foes.size() != 4:
		return _fail("the pack rises: %d" % cq._foes.size())
	game.hud.close_dialogue()
	for foe in cq._foes:
		(foe as SlimeEnemy).take_damage(999999)
	for i in 3:
		await process_frame
	cq._process(0.1)
	if int(cq.steps["toren_trail"]) != 3:
		return _fail("the pack falls — next step")
	await process_frame
	# The last place opens the choice; the chosen item and flag.
	cq.look("toren_trail")
	if not game.hud.dialogue_label.text.contains("Олень привёл меня домой"):
		return _fail("the last place's words open the choice")
	game.dialogues.handle_choice("cq_end:toren_trail:leave")
	if not game.quests.is_completed("toren_trail") or int(hero.inventory.get("stag_feather", 0)) != 1 or not game.director.has_flag("toren_left_bow"):
		return _fail("the story ends: the feather and the flag")
	if not cq.offer_choice("hunter").is_empty():
		return _fail("told once")
	# Raina: the keeper's words come first.
	game.hud.close_dialogue()
	game.dialogues.handle_choice("cq_start:raina_bell")
	game.dialogues.handle_choice("cq_accept:raina_bell")
	await _go(game, "salt_coast", Vector2(900, 560))
	map = game.world.get_world_2d().navigation_map
	for step in cq.info("raina_bell")["steps"]:
		if step.has("position"):
			var at := SkywardGame._vec(step["position"])
			if NavigationServer2D.map_get_closest_point(map, at).distance_to(at) > 24.0:
				return _fail("a place on the coast one can walk to: %s" % str(at))
	if cq.marker("keeper") != "quest" or cq.targets().is_empty():
		return _fail("the keeper is marked and pinned")
	await _bring(game, "captain_raina")
	if not cq.talk("keeper") or int(cq.steps["raina_bell"]) != 1:
		return _fail("the keeper tells of the reefs")
	game.hud.close_dialogue()
	# Saved mid-way.
	var snapshot := game.make_save_snapshot()
	cq.steps.clear()
	if not game.restore_save_snapshot(snapshot) or int(game.companion_quests.steps.get("raina_bell", -1)) != 1 or game.companion_quests.endings.get("toren_trail", "") != "leave":
		return _fail("stories survive a save")
	print("COMPANION QUESTS OK")
	quit()
