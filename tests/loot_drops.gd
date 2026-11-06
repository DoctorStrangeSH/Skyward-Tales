extends SceneTree

## Monster drop tables, coin piles, loot magnet, chest tiers, legendary and
## sword rolls, field crafting from monster materials.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("LOOT DROPS TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var hero := game.player
	hero.global_position = Vector2(1300, 700)
	game.loot_rng.seed = 11

	# Slimes drop gel and coins over many kills.
	var seen := {}
	for i in 40:
		for item in game.roll_drops("slime", Vector2(200, 200)):
			seen[item] = true
	if not seen.has("slime_gel") or not seen.has("gold"):
		return _fail("slimes drop gel and coins: %s" % str(seen.keys()))
	seen.clear()
	for i in 30:
		for item in game.roll_drops("skeleton", Vector2(200, 200)):
			seen[item] = true
	if not seen.has("bone"):
		return _fail("skeletons drop bones")

	# Coins fly into the hero when she is close.
	var gold := hero.gold
	var coins := game._spawn_loot(hero.global_position + Vector2(20, 0), "gold")
	coins.amount = 17
	for i in 60:
		await process_frame
	if hero.gold != gold + 17 or is_instance_valid(coins):
		return _fail("coins are pulled in and picked up")
	var far := game._spawn_loot(hero.global_position + Vector2(200, 0), "slime_gel")
	for i in 20:
		await process_frame
	if not is_instance_valid(far):
		return _fail("far loot stays on the ground")

	# Chest tiers.
	var iron := game.chest_tier_reward("iron", Vector2(400, 400))
	var golden := game.chest_tier_reward("gold", Vector2(400, 400))
	if hero.get_item_definition(iron).get("rarity", "") == "common":
		return _fail("iron chests hold uncommon or better gear")
	if not hero.get_item_definition(golden).get("rarity", "") in ["rare", "epic", "legendary"]:
		return _fail("golden chests hold rare or better gear")
	if game.chest_tier_reward("wood", Vector2.ZERO) != "":
		return _fail("wooden chests give no extra gear")

	# Rolls include legendary items and swords.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var legendary := false
	var blade := false
	for i in 1500:
		if LootGenerator.roll_rarity(rng) == "legendary":
			legendary = true
		var definition := LootGenerator.generate(rng, 5)
		if definition.get("slot", "") == "blade" and int(definition.get("melee", 0)) > 0:
			blade = true
	if not legendary or not blade:
		return _fail("legendaries and swords can drop")

	# Gear stats: crit and lifesteal.
	var crit := hero.get_crit_chance()
	hero.add_item("fang_charm")
	hero.equip_item("fang_charm")
	if hero.get_crit_chance() < crit + 0.039:
		return _fail("the fang charm adds crit chance")

	# Field crafting turns monster materials into potions.
	hero.add_item("slime_gel", 2)
	hero.add_item("healroot", 1)
	var potions := int(hero.inventory.get("health_potion", 0))
	game._handle_key(KEY_B)
	if not game.hud.crafting_visible:
		return _fail("B opens field crafting")
	game.crafting.handle_choice("craft:hand_gel_potion")
	if int(hero.inventory.get("health_potion", 0)) != potions + 1 or hero.inventory.has("slime_gel"):
		return _fail("gel and root become a health potion")
	print("LOOT DROPS OK: drop tables, coins, magnet, chest tiers, legendaries, swords, gear crit, field crafting")
	quit(0)
