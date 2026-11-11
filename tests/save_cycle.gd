extends SceneTree

## Full cycles "save → load → finish the deed → get the reward" and the
## fixes of the owner's review (11 November):
##  1. every enemy kind survives a save (no more slimes instead of Windtail);
##  2. quest objects keep their quest;
##  3. the Keeper of the Cistern and the Guardian of the geode keep their
##     strength and reward after loading;
##  4. echo and memory crystals for recipes can be gathered;
##  5. loading during a minecart ride leaves the hero walking;
##  6. a held attack is dropped when focus is lost / released over the UI;
##  7. a blade does not reach through a wall;
##  8. re-dressing does not refill health or mana;
##  9. a spare copy of a worn item can be sold.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("SAVE CYCLE FAILED: " + reason)
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _kinds(game: SkywardGame) -> Array:
	var result: Array = []
	for node in game.get_children():
		if node is SlimeEnemy and not node.is_queued_for_deletion():
			result.append(SkywardGame.enemy_kind(node))
	result.sort()
	return result

func _find_meta(game: SkywardGame, meta: String) -> SlimeEnemy:
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta(meta) and not node.is_queued_for_deletion():
			return node
	return null

func _chest(game: SkywardGame, id: String) -> bool:
	for node in game.get_children():
		if node is TreasureChest and node.chest_id == id and not node.is_queued_for_deletion():
			return true
	return false

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player

	# 1. Every kind of the registry comes back as itself.
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	var spawned := 0
	for kind in SkywardGame.ENEMY_SCRIPTS:
		var foe := game.spawn_enemy(str(kind), Vector2(900 + spawned * 6, 900))
		if foe == null:
			return _fail("spawn " + str(kind))
		foe.set_physics_process(false)
		if SkywardGame.enemy_kind(foe) != str(kind):
			return _fail("kind of %s reads as %s" % [kind, SkywardGame.enemy_kind(foe)])
		spawned += 1
	var before := _kinds(game)
	if before.size() != SkywardGame.ENEMY_SCRIPTS.size():
		return _fail("all kinds stand")
	var snapshot: Dictionary = game.make_save_snapshot()
	if not game.restore_save_snapshot(snapshot):
		return _fail("the save loads")
	await _frames(2)
	var after := _kinds(game)
	if after != before:
		var lost: Array = []
		for kind in before:
			if not after.has(kind):
				lost.append(kind)
		return _fail("kinds lost on load: %s (slimes: %d → %d)" % [lost, before.count("slime"), after.count("slime")])
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()

	# 2. A quest object keeps its quest.
	game._spawn_herb(Vector2(300, 700), "moonleaf", "Письмо", "haven_letters")
	snapshot = game.make_save_snapshot()
	game.restore_save_snapshot(snapshot)
	await _frames(2)
	var kept := false
	for node in game.get_children():
		if node is WorldCollectible and node.display_name == "Письмо" and not node.is_queued_for_deletion():
			kept = node.quest_id == "haven_letters"
	if not kept:
		return _fail("a quest object keeps its quest after loading")

	# 8. Re-dressing heals nothing.
	hero.add_item("mana_amulet", 2)
	hero.mana = 0
	hero.equip_item("mana_amulet")
	var pool := hero.max_mana
	if hero.mana != 0:
		return _fail("putting an amulet on gives no mana: %d" % hero.mana)
	hero.unequip_slot("amulet")
	hero.equip_item("mana_amulet")
	if hero.mana != 0 or hero.max_mana != pool:
		return _fail("re-dressing gives no mana")
	# 9. One worn, one spare: the spare sells.
	if int(hero.inventory.get("mana_amulet", 0)) != 1 or game.merchant_shop.sellable_count(hero, "mana_amulet") != 1:
		return _fail("the spare copy of a worn item is for sale")
	hero.mana = hero.max_mana

	# 4. Crystals for recipes are gathered.
	game._travel("crystal_caves", Vector2(452, 300))
	await _frames(2)
	var druse: GatherNode = null
	for node in game.get_children():
		if node is GatherNode and node.kind == "echo_crystal":
			druse = node
	if druse == null or not game.crafting.gather(druse) or int(hero.inventory.get("echo_crystal", 0)) != 1:
		return _fail("an echo crystal is chipped off a druse")
	var memory := false
	for entry in RegionCatalog.get_region("sky_island").get("gather", []):
		memory = memory or str(entry.get("kind", "")) == "memory_crystal"
	if not memory or hero.get_item_name("memory_crystal").is_empty():
		return _fail("memory crystals grow on the Sky Island")

	# 3 + 5 + 7. The Old Adit.
	game.adit.enter()
	await _frames(2)
	var guardian := _find_meta(game, "adit_guardian")
	if guardian == null:
		return _fail("the Guardian stands")
	var strong := guardian.max_health
	# 7. Through the wall of the tunnel — no hit; in the open — a hit.
	for node in game.get_children():
		if node is SlimeEnemy and not node.has_meta("adit_guardian"):
			node.free()
	var foe := game.spawn_enemy("slime", Vector2(500, 400))
	foe.set_physics_process(false)
	await physics_frame
	await physics_frame
	hero.global_position = Vector2(500, 436)
	var hits := game.combat._melee_hit(hero.global_position, Vector2.UP, 60.0, 360.0, 1, 0.0)
	if hits != 0:
		return _fail("the blade does not reach through a wall")
	foe.global_position = Vector2(540, 440)
	if game.combat._melee_hit(hero.global_position, Vector2.RIGHT, 60.0, 360.0, 1, 0.0) != 1:
		return _fail("the blade reaches a foe in the open")
	foe.free()
	# 5. Save, ride, load mid-ride: the hero walks.
	hero.global_position = OldAdit.CART_STOPS[0] + Vector2(0, 20)
	snapshot = game.make_save_snapshot()
	game.adit.ride()
	await _frames(3)
	if hero.is_physics_processing():
		return _fail("the ride holds the hero")
	game.restore_save_snapshot(snapshot)
	await _frames(3)
	if not hero.is_physics_processing():
		return _fail("loading during a ride frees the hero")
	# 3. The Guardian after loading: as strong, and the chest appears.
	guardian = _find_meta(game, "adit_guardian")
	if guardian == null or guardian.max_health != strong or not guardian.combat_feedback.elite_name.contains("Страж"):
		return _fail("the Guardian keeps its strength after loading")
	var guardians := 0
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("adit_guardian") and not node.is_queued_for_deletion():
			guardians += 1
	if guardians != 1:
		return _fail("one Guardian, not %d" % guardians)
	game._strike(guardian, 9999999, Vector2.RIGHT, 0.0)
	await _frames(4)
	if not game.adit.guardian_down or not _chest(game, "adit_geode"):
		return _fail("save → load → win → the geode chest")

	# 3. The Keeper of the Cistern, the same cycle.
	game._travel(Cistern.REGION, Vector2(216, 700))
	await _frames(2)
	var keeper := _find_meta(game, "cistern_keeper")
	strong = keeper.max_health
	snapshot = game.make_save_snapshot()
	game.restore_save_snapshot(snapshot)
	await _frames(3)
	keeper = _find_meta(game, "cistern_keeper")
	if keeper == null or keeper.max_health != strong:
		return _fail("the Keeper keeps its strength after loading")
	game._strike(keeper, 9999999, Vector2.RIGHT, 0.0)
	await _frames(4)
	if not game.cistern.cleared or not _chest(game, "cistern_0_keeper"):
		return _fail("save → load → win → the Keeper's chest")

	# 6. A held attack does not stick.
	game._attack_holding = true
	game._charging = true
	hero.charge_rooted = true
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if game._charging or game._attack_holding or hero.charge_rooted:
		return _fail("losing focus drops the charge")
	game._attack_holding = true
	game._charging = true
	hero.charge_rooted = true
	game.hud.inventory_open = true
	var release := InputEventAction.new()
	release.action = "attack"
	release.pressed = false
	game.input_handler._input(release)
	game.hud.inventory_open = false
	if game._charging or game._attack_holding or hero.charge_rooted:
		return _fail("releasing over a window drops the charge")
	print("SAVE CYCLE OK")
	quit(0)
