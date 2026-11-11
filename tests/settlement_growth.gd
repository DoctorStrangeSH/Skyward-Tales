extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("SETTLEMENT GROWTH FAILED: " + message)
	quit(1)

func _resource(game: SkywardGame, kind: String) -> GatherNode:
	for child in game.get_children():
		if child is GatherNode and child.kind == kind and not child.is_queued_for_deletion():
			return child
	return null

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	game.day_night.day = 0
	game.day_night.time = 0.5
	var home := game.settlement.village_region()
	var wood := _resource(game, "wood")
	var stone := _resource(game, "stone")
	if wood == null or stone == null or not wood.growth_enabled or not stone.growth_enabled:
		return _fail("settlement resources enable visible growth")
	game.player.add_item("sapling", 2)
	wood.set_ready(false)
	game.crafting.cooldowns[wood.key] = game.crafting.play_time + 240.0
	if not game._interaction_prompt(wood).contains("посадить саженец"):
		return _fail("the home stump explains the planting action")
	if not game.forestry.try_plant(wood) or wood.stage != "young" or wood.growth_sheet == null:
		return _fail("a planted settlement stump sprouts")
	if not is_equal_approx(float(game.crafting.cooldowns[wood.key]) - game.crafting.play_time, 120.0):
		return _fail("planting halves the remaining wait")
	stone.set_ready(false)
	game.crafting.cooldowns[stone.key] = game.crafting.play_time + 300.0
	game.crafting.play_time += 301.0
	game.crafting.refresh_nodes()
	if not wood.available or not stone.available or wood.growth_sheet == null or stone.growth_sheet == null:
		return _fail("trees and boulders regrow on the play clock")
	game.settlement.buildings["farm"] = 1
	game.farm.refresh()
	game.player.add_item("seed_healroot", 2)
	if not game.farm.plant(0, "seed_healroot"):
		return _fail("settlement seeds can be planted")
	game._set_region("moonlit_grove", Vector2(200, 400), false)
	await process_frame
	await process_frame
	wood = _resource(game, "wood")
	if wood == null:
		return _fail("outside resource exists")
	for child in game.get_children():
		if child is GatherNode and not child.is_queued_for_deletion() and child.growth_enabled:
			return _fail("growth presentation leaks to another island")
	if not game.crafting.gather(wood):
		return _fail("ordinary outside gathering still works")
	if game._interaction_prompt(wood).contains("посадить"):
		return _fail("outside stumps must not offer planting")
	var saplings := int(game.player.inventory.get("sapling", 0))
	var cooldown := float(game.crafting.cooldowns[wood.key])
	if game.forestry.try_plant(wood) or int(game.player.inventory.get("sapling", 0)) != saplings or float(game.crafting.cooldowns[wood.key]) != cooldown:
		return _fail("outside planting must not consume or accelerate anything")
	game.crafting.cooldowns[wood.key] = game.crafting.play_time + 1.0
	game.forestry.update_stage(wood)
	if wood.stage != "cut" or wood.growth_sheet != null:
		return _fail("outside stump has no cultivated growth stages")
	game.crafting.play_time += 2.0
	game.crafting.refresh_nodes()
	if not wood.available or wood.growth_sheet != null:
		return _fail("ordinary outside respawn is preserved")
	var seeds := int(game.player.inventory.get("seed_healroot", 0))
	if game.farm.plant(1, "seed_healroot") or int(game.player.inventory.get("seed_healroot", 0)) != seeds:
		return _fail("stale garden choices cannot plant on another island")
	game.day_night.day += 1
	if not game.farm.ripe(0) or game.farm.harvest(0) or not game.farm.beds.has(0):
		return _fail("home crops grow while away and cannot be harvested remotely")
	game._set_region(home, Vector2(700, 800), false)
	await process_frame
	await process_frame
	if not game.farm.harvest(0):
		return _fail("the grown crop can be harvested after returning")
	game.queue_free()
	var audio := GameAudio.instance()
	if audio != null:
		audio._release()
		audio.queue_free()
	for frame in 12:
		await process_frame
	print("SETTLEMENT GROWTH OK")
	quit(0)
