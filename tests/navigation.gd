extends SceneTree

## Quest targets on the minimap and world map, the gate towards the goal,
## travel by clicking a land on the world map, respawning monsters,
## timed autosave.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("NAVIGATION TEST FAILED: " + reason)
	quit(1)

func _kinds(markers: Array, kind: String) -> Array:
	return markers.filter(func(m: Dictionary) -> bool: return m["kind"] == kind)

func _slimes(game: SkywardGame) -> int:
	var count := 0
	for node in game.get_children():
		if node is SlimeEnemy and SkywardGame.enemy_kind(node) == "slime" and not node.is_queued_for_deletion():
			count += 1
	return count

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.events.enabled = false

	# A new game: the elder offers the first quest.
	game.quest_nav.refresh()
	if _kinds(game.quest_nav.minimap_markers(), "quest").is_empty():
		return _fail("quest givers are marked")
	# The prologue: the fallen shard in Greenreach is a gold goal here.
	game.quests.start_quest("main_prologue")
	game.quest_nav.refresh()
	var here := game.quest_nav.minimap_markers()
	var goals := _kinds(here, "goal_main")
	if goals.is_empty() or not (goals[0]["position"] as Vector2).is_equal_approx(Vector2(1300, 330)):
		return _fail("the prologue's shard is marked on the minimap: %s" % [here])

	# A goal in other lands: the minimap points at the right gate.
	game.quests.states["main_prologue"]["completed"] = true
	game.quests.states["main_echoes"]["started"] = true
	game.quests.active_quest_id = "main_echoes"
	game.quest_nav.refresh()
	var badges := game.quest_nav.region_badges()
	for region_id in ["misty_marsh", "salt_coast", "stone_pass"]:
		if not badges.get(region_id, {}).has("main"):
			return _fail("world map badge for " + region_id)
	if game.quest_nav.main_region() != "salt_coast":
		return _fail("the nearest goal land is the coast, got " + game.quest_nav.main_region())
	var gate_marks := _kinds(game.quest_nav.minimap_markers(), "goal_gate")
	var coast_gate := RegionCatalog.gate("greenreach", "salt_coast")
	if gate_marks.size() != 1 or not (gate_marks[0]["position"] as Vector2).is_equal_approx(SkywardGame._vec(coast_gate.get("position"))):
		return _fail("the gate towards the goal is marked")
	if QuestNav.route("greenreach", "sky_heart") != ["greenreach", "moonlit_grove", "crystal_caves", "sky_island", "wind_spires", "sky_rift", "sky_heart"]:
		return _fail("route over the gates: %s" % [QuestNav.route("greenreach", "sky_heart")])

	# Travel by clicking a land with an awakened stone.
	game.director.set_flag("waystone_moonlit_grove")
	game.director.set_flag("seen_vail_grove")
	game.open_map(true)
	var overview: WorldOverview = game.hud.world_map_view.overview
	if not overview.visible or not overview.awake.has("moonlit_grove"):
		return _fail("the world tab shows awakened stones")
	if not overview.badges.get("salt_coast", {}).has("main") or overview.goal_route.size() != 2:
		return _fail("the world tab shows quest badges and the road to the goal")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = overview._rect("moonlit_grove").get_center()
	overview._gui_input(click)
	if game.current_region != "moonlit_grove" or game.hud.world_map_visible:
		return _fail("clicking the grove travels there")
	await process_frame

	# Ordinary monsters come back; the hero is far away.
	game._set_region("greenreach", Vector2(130, 210), false)
	await process_frame
	var before := _slimes(game)
	var slime: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and SkywardGame.enemy_kind(node) == "slime":
			slime = node
			break
	slime.take_damage(99999)
	await process_frame
	if _slimes(game) != before - 1:
		return _fail("the slime falls")
	game.player.global_position = Vector2(1800, 1200)
	game._process_respawns(SkywardGame.ENEMY_RESPAWN + 1.0)
	if _slimes(game) != before:
		return _fail("the slime comes back after a while (%d/%d)" % [_slimes(game), before])

	# Autosave every two minutes of play.
	game.autosave_enabled = true
	game._autosave_clock = SkywardGame.AUTOSAVE_INTERVAL - 0.1
	game._tick_autosave(0.5)
	if not game._autosave_pending:
		return _fail("timed autosave")
	await process_frame
	if game.hud.save_indicator == null:
		return _fail("the save badge appears")
	print("NAVIGATION OK: quest markers, gate to the goal, world map travel, respawn, autosave")
	quit(0)
