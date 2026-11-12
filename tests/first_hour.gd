extends SceneTree

## Этап 22, «первые 30–60 минут»: fixes found by the first-hour bot
## (tools/first_hour_bot.gd).
##  1. An autosave waits while the hero is in a fight or badly wounded — a
##     load after a defeat no longer drops the hero back into the same fight.
##  2. The quarry of an active hunt comes back sooner (10 s instead of 40).
##  3. A story boss called up by a scene gets a map pin where it stands.
##  4. Newer villagers have portraits in dialogue (from their look).
##  5. A story scene shields the frozen hero and stills the foes around.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("FIRST HOUR FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.events.enabled = false
	game.autosave_enabled = true
	game.save_path = "user://first_hour_test.json"
	var hero := game.player
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()

	# 1. Danger postpones the autosave; it happens once the danger is over.
	if game.in_danger() or not game.autosave():
		return _fail("a quiet moment saves")
	var foe := game.spawn_enemy("wolf", hero.global_position + Vector2(60, 0))
	foe.set_physics_process(false)
	if not game.in_danger() or game.autosave():
		return _fail("a wolf next to the hero postpones the save")
	foe.free()
	hero.health = int(hero.max_health * 0.3)
	if not game.in_danger():
		return _fail("low health is danger too")
	hero.health = hero.max_health
	if game.in_danger():
		return _fail("safe again")
	game._autosave_clock = 0.3
	game._tick_autosave(0.3)
	await process_frame
	if game._autosave_waiting:
		return _fail("the postponed save is made when safe")

	# 2. Hunt quarry respawns sooner.
	game.quests.start_quest("toren_wolf_hunt")
	if not game._hunted_kinds().has("wolf"):
		return _fail("the wolf hunt is a hunt")
	game._respawns.append({"region": game.current_region, "data": {"kind": "wolf", "position": [hero.global_position.x + 600, hero.global_position.y]}, "at": game._play_clock + 40.0})
	game._process_respawns(0.1)
	game._process_respawns(SkywardGame.HUNT_RESPAWN + 0.5)
	var wolves := 0
	for node in game.get_children():
		if node is SlimeEnemy and SkywardGame.enemy_kind(node) == "wolf":
			wolves += 1
	if wolves != 1:
		return _fail("the hunted wolf came back within %d s" % int(SkywardGame.HUNT_RESPAWN))

	# 3. A live story boss is pinned.
	game.quests.start_quest("main_echo")
	game._travel("crystal_caves", Vector2(900, 600))
	await process_frame
	await process_frame
	for node in game.get_children():
		if node is WorldCollectible or node is SlimeEnemy:
			node.free()
	var echo := game.spawn_enemy("echo", hero.global_position + Vector2(100, 40))
	echo.set_physics_process(false)
	game.quest_nav.refresh()
	var pinned := false
	for target in game.quest_nav.targets:
		if str(target["kind"]) == "main" and target["position"] is Vector2 and (target["position"] as Vector2).distance_to(echo.global_position) < 1.0:
			pinned = true
	if not pinned:
		return _fail("the Echo standing here is pinned")
	echo.free()

	# 5. A story scene shields the frozen hero; foes hold still.
	var wolf := game.spawn_enemy("wolf", hero.global_position + Vector2(20, 0))
	game.story.play("guardian_freed")
	var before := hero.health
	hero.take_damage(30, wolf)
	var spot := wolf.global_position
	for i in 20:
		await physics_frame
	if hero.health != before or wolf.global_position.distance_to(spot) > 0.5:
		return _fail("a story scene shields the hero and stills the foes")
	game.story.skip()
	hero.take_damage(30, wolf)
	if hero.health != before:
		return _fail("a short grace after the scene")
	wolf.free()
	# A finished quest is saved even with a foe nearby.
	var near := game.spawn_enemy("wolf", hero.global_position + Vector2(40, 0))
	near.set_physics_process(false)
	game.quests.quest_completed.emit("main_echo")
	if not game.autosave():
		return _fail("progress is saved at once")
	near.free()

	# 4. Portraits by look.
	if RegionCatalog.portrait_id("caves_miner_senya").is_empty() or RegionCatalog.portrait_id("Сеня, молодой рудокоп").is_empty():
		return _fail("Senya has a portrait through her look")
	game.hud._set_speaker("Сеня, молодой рудокоп")
	if game.hud.dialogue_portrait.texture == null:
		return _fail("the dialogue shows Senya's portrait")
	# 6. "Всё собрано" names whom to go back to.
	if not game.pickups.return_line("main_spires").contains("Мир"):
		return _fail("runes collected: talk to Mira — " + game.pickups.return_line("main_spires"))
	if not game.pickups.return_line("moonleaf_gathering").contains("Элиан"):
		return _fail("moonleaves: back to Elian — " + game.pickups.return_line("moonleaf_gathering"))
	print("FIRST HOUR OK")
	quit()
