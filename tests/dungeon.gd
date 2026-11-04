extends SceneTree

## The ruins depths: stairs below the greenreach ruins, skeletons, spike
## traps that hurt only when raised, a key chest, a locked grate that opens
## with the key (saved), and the Crypt Lord who raises skeletons.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("DUNGEON TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _all(script_name: String) -> Array:
	var found := []
	for node in game.get_children():
		if not node.is_queued_for_deletion() and node.get_script() != null and node.get_script().get_global_name() == script_name:
			found.append(node)
	return found

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game._on_region_travel("ruins_depths", Vector2(224, 860))
	await process_frame
	if not _verify(game.current_region == "ruins_depths", "stairs lead into the depths"):
		return
	if not _verify(_all("Skeleton").size() == 6 and _all("CryptLord").size() == 1, "skeletons and their lord"):
		return
	var skeleton: SlimeEnemy = _all("Skeleton")[0]
	if not _verify(skeleton.visual.chibi_id == "skeleton", "skeletons in the pack style"):
		return

	# Spike traps.
	var trap: SpikeTrap = _all("SpikeTrap")[0]
	var hero := game.player
	hero.global_position = trap.global_position
	hero.set_physics_process(false)
	trap.clock = SpikeTrap.UP_TIME + 0.1
	trap.raised = false
	var hp := hero.health
	trap._process(0.0)
	if not _verify(hero.health == hp, "lowered spikes are safe"):
		return
	trap.clock = 0.0
	trap._process(0.01)
	if not _verify(hero.health < hp, "raised spikes hurt"):
		return

	# Locked grate and its key.
	var door: DungeonDoor = _all("DungeonDoor")[0]
	door.interact()
	if not _verify(not door.is_open, "the grate needs a key"):
		return
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == "ruins_key_chest":
			node.interact()
	if not _verify(int(hero.inventory.get("ruins_key", 0)) == 1, "the key is in a chest"):
		return
	door.interact()
	if not _verify(door.is_open and not hero.inventory.has("ruins_key") and game.opened_doors.has("ruins_gate"), "the key opens the grate"):
		return

	# The Crypt Lord.
	var lord: CryptLord = _all("CryptLord")[0]
	if not _verify(lord.visual.chibi_id == "crypt_lord" and SkywardGame.enemy_kind(lord) == "crypt_lord", "the Crypt Lord in his own look"):
		return
	var before := _all("Skeleton").size()
	lord.take_damage(lord.max_health / 2 + 5)
	await process_frame
	if not _verify(_all("Skeleton").size() == before + 2, "enraged, he raises two skeletons"):
		return
	lord.take_damage(9999)
	await process_frame
	if not _verify(game.director.has_flag("crypt_lord_defeated"), "the lord stays dead"):
		return

	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "save restores"):
		return
	var open := false
	for node in restored.get_children():
		if node is DungeonDoor and node.door_id == "ruins_gate":
			open = node.is_open
	if not _verify(open, "the grate stays open after loading"):
		return
	print("DUNGEON OK: stairs, skeletons, traps, key, grate, Crypt Lord, save/load")
	quit(0)
