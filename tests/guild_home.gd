extends SceneTree

## Adventurers' Guild bounties (offers, the named target, turn-in, ranks,
## "Гроза" bounties at level 2) and the heroine's home (sleep till morning).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("GUILD TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	game.day_night.paused = true
	var hero := game.player
	hero.max_health = 99999
	hero.health = 99999
	hero.level = 8
	hero.gold = 5000
	for item in ["wood", "stone", "iron_ore", "obsidian_shard", "wolf_pelt"]:
		hero.add_item(item, 40)
	game.visited_regions["moonlit_grove"] = true
	game.visited_regions["salt_coast"] = true

	# The guild.
	game.settlement.upgrade("guild")
	await process_frame
	var ragna: WorldNpc = null
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "guild_master":
			ragna = node
	if ragna == null:
		return _fail("Ragna at the guild")
	ragna.interact()
	var guild := game.guild
	if guild.offers.size() != 3 or guild.offers.any(func(o: Dictionary) -> bool: return bool(o["mighty"])):
		return _fail("three ordinary bounties at level 1")
	if not str(guild.offers[0]["name"]).contains("«"):
		return _fail("bounties have names")
	game.dialogues.handle_choice("guild_take:0")
	if guild.active.is_empty() or (guild.active["position"] as Array).size() != 2:
		return _fail("bounty taken with a place")
	game.quest_nav.refresh()
	if not game.quest_nav.region_badges().get(str(guild.active["region"]), {}).has("side"):
		return _fail("the target is on the world map")

	# Hunt it down.
	var pos: Array = guild.active["position"]
	game._set_region(str(guild.active["region"]), Vector2(float(pos[0]), float(pos[1]) + 60.0), false)
	await process_frame
	var target: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("bounty"):
			target = node
	if target == null or not target.combat_feedback.elite_name.begins_with("☠"):
		return _fail("the named monster waits")
	target.take_damage(9999999)
	await process_frame
	if not bool(guild.active.get("done", false)):
		return _fail("bounty done")
	game._set_region("greenreach", Vector2(500, 1120), false)
	await process_frame
	var gold := hero.gold
	game.dialogues.handle_choice("guild_turnin")
	if guild.finished != 1 or hero.gold <= gold or not guild.active.is_empty():
		return _fail("pay collected")

	# Ranks.
	guild.finished = 4
	guild.active = {"id": "x", "name": "Тест", "region": "salt_coast", "kind": "crab", "gold": 100, "xp": 100, "mighty": false, "position": [400, 600], "done": true}
	guild.turn_in()
	if guild.rank_name() != "Бронза" or not is_equal_approx(guild.reward_mult(), 1.2):
		return _fail("rank Bronze: +20%% (%s)" % guild.rank_name())

	# Level 2: a "Гроза" bounty.
	game.settlement.upgrade("guild")
	guild.offers.clear()
	guild.fill_offers()
	if not guild.offers.any(func(o: Dictionary) -> bool: return bool(o["mighty"])):
		return _fail("level 2 offers a mighty bounty")

	# Home: sleep till morning.
	game.settlement.upgrade("home")
	await process_frame
	var door: SettlementObject = null
	for node in game.get_children():
		if node is SettlementObject and node.kind == "door":
			door = node
	if door == null or game._interaction_prompt(door) != "E — войти в дом":
		return _fail("home door")
	game.day_night.time = 0.6
	var day := game.day_night.day
	hero.health = 10
	door.interact()
	game.dialogues.handle_choice("home_sleep")
	if game.day_night.day != day + 1 or not is_equal_approx(game.day_night.time, 0.27) or hero.health != hero.max_health:
		return _fail("sleep till morning, rested")
	if not hero.buffs.has("power"):
		return _fail("rested buff")
	var snap := guild.make_snapshot()
	guild.finished = 0
	guild.restore_snapshot(snap)
	if guild.finished != 5:
		return _fail("guild saved")
	print("GUILD OK: bounties, named target, pay, ranks, mighty bounties, home sleep")
	quit(0)
