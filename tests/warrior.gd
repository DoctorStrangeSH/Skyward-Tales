extends SceneTree

## The warrior's kit: parry (stagger + riposte), block, hit streak, and the
## special effects of epic and legendary gear.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("WARRIOR TEST FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	for node in game.get_children():
		if node is SlimeEnemy:
			node.queue_free()
	await process_frame
	var hero := game.player
	hero.max_health = 1000
	hero.health = 1000
	var foe := game.spawn_enemy("wolf", hero.global_position + Vector2(20, 0))
	foe.set_physics_process(false)
	foe.max_health = 99999
	foe.health = 99999

	# Parry: no shield — no guard (owner's list №25).
	if hero.start_guard():
		return _fail("guarding needs a shield")
	hero.add_item("wooden_shield")
	hero.equip_item("wooden_shield")
	if not hero.start_guard() or not hero.blocking:
		return _fail("guard up")
	hero.take_damage(30, foe)
	if hero.health != 1000 or foe.slow_time_left <= 0.0 or game.gear.riposte_left <= 0.0:
		return _fail("a parry takes no damage and staggers the attacker")
	if game.achievements.progress("parry_10") != 1:
		return _fail("parries are counted")
	var hp := foe.health
	game._strike(foe, 10, Vector2.RIGHT, 0.0)
	if hp - foe.health < 25:
		return _fail("riposte hits hard (%d)" % (hp - foe.health))

	# Block after the parry window: most damage is stopped.
	hero.parry_left = 0.0
	hero.take_damage(50, foe)
	var blocked_loss := 1000 - hero.health
	hero.end_guard()
	hero.health = 1000
	hero.take_damage(50, foe)
	var open_loss := 1000 - hero.health
	if blocked_loss <= 0 or blocked_loss >= open_loss:
		return _fail("block softens the blow (%d vs %d)" % [blocked_loss, open_loss])
	hero.health = 1000

	# Hit streak.
	foe.slow_time_left = 0.0
	foe.slow_factor = 1.0
	for i in 10:
		game._strike(foe, 10, Vector2.RIGHT, 0.0)
	if game.gear.streak != 10 or not is_equal_approx(game.gear.streak_mult(), 1.15):
		return _fail("ten blows: on a roll")
	if game.hud.streak_label == null or not game.hud.streak_label.visible:
		return _fail("streak counter shows")
	hero.take_damage(5, foe)
	if game.gear.streak != 0:
		return _fail("a wound ends the streak")

	# Gear effects.
	hero.equipment["blade"] = "skyclaw_blade"
	game.gear._strikes = 0
	foe.shock_time_left = 0.0
	for i in 4:
		game._strike(foe, 5, Vector2.RIGHT, 0.0)
	if foe.shock_time_left <= 0.0:
		return _fail("skyclaw calls a star bolt")
	hero.equipment["blade"] = ""

	hero.equipment["amulet"] = "toad_crown"
	foe.burn_time_left = 0.0
	hero.take_damage(5, foe)
	if foe.burn_time_left <= 0.0:
		return _fail("toad crown poisons attackers")

	hero.equipment["amulet"] = "spark_collar"
	game.gear.on_dodge()
	foe.shock_time_left = 0.0
	foe.slow_time_left = 0.0
	game._strike(foe, 5, Vector2.RIGHT, 0.0)
	if foe.shock_time_left <= 0.0:
		return _fail("spark collar shocks after a dodge")

	hero.equipment["blade"] = "jelly_staff"
	foe.slow_time_left = 0.0
	game.on_spell_hit(foe)
	if foe.slow_time_left <= 0.0:
		return _fail("jelly staff slows")

	hero.equipment["relic"] = "dusk_fang"
	game.day_night.paused = true
	game.day_night.time = 0.9
	hero.health = 500
	game.gear.on_kill()
	if hero.health <= 500:
		return _fail("dusk fang heals at night")

	hero.equipment["relic"] = "golem_heart"
	hero.health = 100
	if hero.get_damage_reduction() < 0.3:
		return _fail("golem heart hardens when low")
	if not game.player.get_item_definition("skyclaw_blade").get("description", "").contains("Особое"):
		return _fail("special effects are described")
	print("WARRIOR OK: parry, riposte, block, streak, gear effects")
	quit(0)
