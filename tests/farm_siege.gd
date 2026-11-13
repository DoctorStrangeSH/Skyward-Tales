extends SceneTree

## Этап 24: the defence errand — waves go for the barn, the barn can fall
## (the errand waits for another try), three waves won pay and are kept.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("FARM SIEGE FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var siege := game.siege
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	if siege.available():
		return _fail("not before the first chapter")
	game.quests.states["moonleaf_gathering"]["started"] = true
	game.quests.states["moonleaf_gathering"]["completed"] = true
	while hero.level < 6:
		hero.add_experience(hero.experience_to_next)
	for quest_id in game.quests.definitions:
		if str(game.quests.definitions[quest_id].get("giver", "")) == FarmSiege.NPC:
			pass
	siege.start()
	if not siege.active or siege.barn == null:
		return _fail("the siege begins with a barn")
	for i in 10:
		await physics_frame
	siege._pause = 0.0
	siege._process(0.1)
	if siege._foes.size() != 4 or siege.wave != 1:
		return _fail("the first wave: 4 foes, got %d" % siege._foes.size())
	for foe in siege._foes:
		if (foe as SlimeEnemy).taunt != siege.barn:
			return _fail("the wave goes for the barn")
	# The barn falls: the siege is off, the errand stays.
	siege.barn.take_damage(9999)
	siege._process(0.1)
	if siege.active or not game.quests.is_active(FarmSiege.QUEST):
		return _fail("a fallen barn calls the siege off, the errand waits")
	for i in 3:
		await process_frame
	# Again, and win: kill every wave.
	siege.start()
	for w in 3:
		siege._pause = 0.0
		siege._process(0.1)
		if siege._foes.is_empty():
			return _fail("wave %d" % (w + 1))
		for foe in siege._foes:
			(foe as SlimeEnemy).take_damage(99999)
		for i in 3:
			await process_frame
		siege._process(0.1)
	siege._pause = 0.0
	var gold := hero.gold
	siege._process(0.1)
	if siege.active or not game.quests.is_completed(FarmSiege.QUEST) or hero.gold < gold + 160:
		return _fail("three waves won: the errand is done and paid")
	if not game.director.has_flag("farm_defended"):
		return _fail("the farm remembers")
	print("FARM SIEGE OK")
	quit()
