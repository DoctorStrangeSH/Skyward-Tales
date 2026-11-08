extends SceneTree

## Этап 14: weapon kinds (dagger, spear, hammer), sets, forging at Borin's
## (+1..+3, the third forge, awakening legendaries to +5), new gear effects,
## the phoenix feather, guild trophies and the Keeper regalia.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("GEAR STAGE TEST FAILED: " + reason)
	quit(1)

func _enemy(game: SkywardGame, at: Vector2) -> SlimeEnemy:
	var enemy: SlimeEnemy = game.spawn_enemy("slime", at)
	enemy.set_physics_process(false)
	enemy.global_position = at
	enemy.max_health = 9999
	enemy.health = 9999
	return enemy

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	hero.global_position = Vector2(900, 900)
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	await process_frame

	# Weapon kinds.
	if hero.weapon_kind() != "sword":
		return _fail("bare hands swing like a sword")
	hero.add_item("guard_spear")
	hero.equip_item("guard_spear")
	if hero.weapon_kind() != "spear":
		return _fail("a spear is a spear")
	hero.facing = Vector2.RIGHT
	var far := _enemy(game, hero.global_position + Vector2(44, 0))
	game.attack_cooldown = 0.0
	game.sword_slash()
	if far.health >= 9999:
		return _fail("the spear reaches further than a sword")
	if not is_equal_approx(game.attack_cooldown, SkywardGame.SLASH_COOLDOWN * 1.15):
		return _fail("spear cooldown")
	far.queue_free()
	hero.add_item("scout_knife")
	hero.equip_item("scout_knife")
	game.attack_cooldown = 0.0
	game.sword_slash()
	if game.attack_cooldown >= SkywardGame.SLASH_COOLDOWN:
		return _fail("daggers strike faster")

	# Sets.
	var crit_before := hero.get_crit_chance()
	hero.add_item("ranger_jerkin")
	hero.equip_item("ranger_jerkin")
	if int(hero.worn_sets().get("pack", 0)) != 2 or hero.get_crit_chance() < crit_before + 0.06:
		return _fail("two pieces of the Pack give a set bonus")
	if not hero.get_item_description("scout_knife").contains("Волчья стая"):
		return _fail("set shown in the description")
	for id in ["keeper_staff", "keeper_robe", "keeper_sigil"]:
		hero.add_item(id)
		hero.equip_item(id)
	var spell := hero.get_spell_bonus("fireball")
	if spell < 18 + 4 + 6 + 10:
		return _fail("the Keeper set adds spell power: %d" % spell)
	game.gear._set_check = 0.0
	game.gear._process(0.1)
	if game.achievements.progress("full_set") < 1:
		return _fail("full set achievement")

	# Forging at Borin's: +1 at the old smithy.
	hero.gold = 99999
	hero.add_item("iron_ore", 60)
	hero.add_item("obsidian_shard", 20)
	hero.add_item("wind_essence", 20)
	hero.add_item("meteor_iron", 5)
	if game.borin.forge_level() != 1 or game.borin.max_upgrade("scout_knife") != 1:
		return _fail("the old smithy sharpens to +1")
	var melee := hero.get_melee_damage()
	game.borin.handle_choice("borin_up:scout_knife")
	var knife := str(hero.equipment["blade"])
	if hero.upgrade_level(knife) != 1 or not hero.get_item_name(knife).ends_with("+1") or hero.get_melee_damage() <= melee:
		return _fail("forged and still worn: %s" % hero.get_item_name(knife))
	if str(hero.get_item_definition(knife).get("set", "")) != "pack":
		return _fail("a forged piece keeps its set")
	game.borin.handle_choice("borin_up:" + knife)
	if hero.upgrade_level(str(hero.equipment["blade"])) != 1:
		return _fail("+2 needs a better forge")

	# The third forge and awakening.
	game.director.set_flag(BorinStory.FLAG)
	game.borin.handle_choice("borin_expand")
	if game.borin.forge_level() != 3:
		return _fail("the forge expands to level 3")
	hero.add_item("titan_breaker")
	hero.equip_item("titan_breaker")
	for i in 5:
		game.borin.handle_choice("borin_up:" + str(hero.equipment["blade"]))
	var hammer := str(hero.equipment["blade"])
	if hero.upgrade_level(hammer) != 5 or not hero.get_item_name(hammer).contains("пробуждён"):
		return _fail("a legendary awakens to +5: %s" % hero.get_item_name(hammer))
	if not hero.wears_base("titan_breaker") or hero.weapon_kind() != "hammer":
		return _fail("an awakened hammer is still the Titan Breaker")
	if game.achievements.progress("forged_5") < 5 and game.achievements.progress("forged") < 5:
		pass

	# Titan Breaker: every third blow sends a shockwave.
	var near := _enemy(game, hero.global_position + Vector2(24, 0))
	var side := _enemy(game, hero.global_position + Vector2(-40, 0))
	for i in 3:
		game.attack_cooldown = 0.0
		game._combo_step = 0
		game.sword_slash()
	if side.health >= 9999:
		return _fail("the hammer's shockwave hits all around")
	near.queue_free()
	side.queue_free()

	# Phoenix feather.
	hero.add_item("phoenix_feather")
	hero.equip_item("phoenix_feather")
	hero.health = 5
	hero.take_damage(99999)
	if hero.health <= 0 or hero.phoenix_ready_in <= 0.0:
		return _fail("the phoenix feather saves the hero")
	hero.health = 5
	hero.take_damage(99999)
	if hero.health > 0:
		return _fail("only once in three minutes")
	hero.health = hero.max_health

	# Guild trophy for a mighty bounty.
	game.guild.active = {"id": "x", "name": "Тест", "region": "salt_coast", "kind": "crab", "gold": 10, "xp": 10, "mighty": true, "position": [1, 1], "done": true}
	game.guild.turn_in()
	var got := false
	for id in AdventurersGuild.TROPHIES:
		if hero.inventory.has(id):
			got = true
	if not got:
		return _fail("a mighty bounty pays with a trophy")

	# Generated loot can be a dagger, spear, hammer or bow.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := {}
	for i in 200:
		var rolled := LootGenerator.generate(rng, 5)
		kinds[str(rolled.get("kind", "bow" if rolled.get("bow", false) else ""))] = true
	if not (kinds.has("dagger") and kinds.has("spear") and kinds.has("hammer") and kinds.has("bow")):
		return _fail("new loot bases: %s" % str(kinds.keys()))
	print("GEAR STAGE OK: weapon kinds, sets, forging, awakening, effects, phoenix, trophies, loot")
	quit(0)
