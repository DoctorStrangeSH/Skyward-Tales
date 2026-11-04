extends SceneTree

## Pack sprites (tools/art/chibi.py): both heroes, Mira and the villagers use
## chibi sheets with their own frame counts; idle loops when standing, the
## roll plays on dodge, the charge on cast, Mira throws her vials.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CHIBI TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	for id in ["hero_f", "hero_m", "cartographer", "elder", "merchant", "hunter", "blacksmith", "miner", "grove_warden", "archivist", "vail", "herbalist", "alchemist"]:
		if not DirectionalSprite.has_chibi(id):
			return _fail("no chibi sheet for " + id)
		if not ResourceLoader.exists("res://assets/sprites/portraits/%s.png" % id):
			return _fail("no portrait for " + id)
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	if hero.visual.chibi_id != "hero_m" or hero.visual.hframes != 6:
		return _fail("the hero uses the chibi sheet")
	if not hero.visual.texture.resource_path.ends_with("idle.png"):
		return _fail("standing still plays the idle loop")
	hero.set_identity("Арина", "f")
	if hero.visual.chibi_id != "hero_f":
		return _fail("the heroine uses Legacy Red")
	hero.visual.set_moving(true)
	if not hero.visual.texture.resource_path.ends_with("walk.png"):
		return _fail("moving switches to the walk")
	hero.start_dodge()
	if not hero.visual.is_playing_action() or hero.visual.hframes != 10:
		return _fail("dodging plays the 10-frame roll")
	for _i in range(40):
		await physics_frame
	if hero.visual.is_playing_action() or hero.visual.hframes != 6:
		return _fail("after the roll the walk/idle sheet is back")
	hero.play_cast(Vector2.RIGHT)
	if hero.visual.hframes != 5:
		return _fail("casting plays the charge")
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "blacksmith":
			if node.visual.chibi_id != "blacksmith" or node.visual.hframes != 8:
				return _fail("Borin works at his anvil")
	game.ensure_companion()
	game.spawn_enemy("slime", game.companion.global_position + Vector2(60, 0))
	game.companion.attack_ready_in = 0.0
	await process_frame
	await process_frame
	if game.companion.visual.chibi_id != "cartographer" or game.companion.visual.hframes != 12:
		return _fail("Mira throws a vial")
	print("CHIBI OK: 13 characters with portraits, idle/walk, roll, cast, throw, NPC idles")
	quit(0)
