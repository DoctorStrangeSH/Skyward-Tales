extends SceneTree

## Этап 24: the vault descent — after the warden a stair leads deeper; each
## depth is harder and fills the descent chest; take it at the stair, lose
## it by falling (a reload), keep it by walking out.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("VAULT DESCENT FAILED: " + reason)
	quit(1)

func _warden(game: SkywardGame) -> SlimeEnemy:
	for node in game.get_children():
		if node is SlimeEnemy and not node.is_queued_for_deletion() and node.combat_feedback.elite_name.begins_with("♦"):
			return node
	return null

func _beat_warden(game: SkywardGame) -> bool:
	game.player.global_position = Expeditions.hall_rect(Expeditions.BOSS_HALL).get_center() + Vector2(0, 60)
	await process_frame
	await process_frame
	var warden := _warden(game)
	if warden == null:
		return false
	warden.set_physics_process(false)
	warden.take_damage(999999)
	for i in 3:
		await process_frame
	return true

func _stair(game: SkywardGame) -> TowerObject:
	for node in get_nodes_in_group("vault_stair"):
		if not node.is_queued_for_deletion():
			return node
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	var ex := game.expeditions
	ex.start()
	await process_frame
	if not await _beat_warden(game) or not ex.warden_down:
		return _fail("the first warden")
	if _stair(game) == null:
		return _fail("a dark stair opens after the warden")
	var power := ex.power()
	var reward := ex.reward_mult()
	if not ex.descend():
		return _fail("going deeper")
	await process_frame
	await process_frame
	if ex.depth != 1 or ex.modifier == "calm" or ex.warden_down or absf(ex.power() - power * 1.25) > 0.001:
		return _fail("depth 1: a new trial, foes +25%")
	if ex.reward_mult() <= reward:
		return _fail("deeper pays more")
	var gold := hero.gold
	if not await _beat_warden(game):
		return _fail("the depth-1 warden")
	if ex.bank_gold <= 0 or ex.bank_items.size() != 1 or hero.gold != gold:
		return _fail("the warden below fills the chest, not the floor (%d, %d)" % [ex.bank_gold, ex.bank_items.size()])
	# Take it at the stair.
	var banked := ex.bank_gold
	var bag := hero.inventory.size()
	ex.offer_descent()
	game.dialogues.handle_choice("vault_cash")
	if hero.gold != gold + banked or hero.inventory.size() != bag + 1 or ex.bank_gold != 0:
		return _fail("the chest taken: gold and a find in the bag")
	# Deeper again, fill the chest, then "fall": a reload loses it.
	ex.descend()
	await process_frame
	await process_frame
	await _beat_warden(game)
	if ex.depth != 2 or ex.bank_gold <= 0 or str(ex.bank_items[0]) != "epic":
		return _fail("depth 2: an epic find in the chest")
	var snapshot := game.make_save_snapshot()
	gold = hero.gold
	game.restore_save_snapshot(snapshot)
	if game.expeditions.bank_gold != 0 or game.expeditions.depth != 0 or game.player.gold != gold:
		return _fail("a fall (reload) loses the chest")
	if game.expeditions.deepest != 2 or int(game.achievements.stats.get("depth", 0)) != 2:
		return _fail("the deepest depth is remembered")
	# Walking out keeps it.
	ex = game.expeditions
	hero = game.player
	ex.start()
	await process_frame
	await _beat_warden(game)
	ex.descend()
	await process_frame
	await process_frame
	await _beat_warden(game)
	banked = ex.bank_gold
	gold = hero.gold
	game._travel("greenreach", Vector2(900, 600))
	for i in 3:
		await process_frame
	if hero.gold != gold + banked or ex.active:
		return _fail("walking out takes the chest along")
	print("VAULT DESCENT OK")
	quit()
