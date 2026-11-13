extends SceneTree

## Этап 24: joint actions with companions (G) — each companion beside the
## hero adds a piece; one cooldown.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("JOINT ACTIONS FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	var joint := game.joint
	if joint.trigger():
		return _fail("alone: no joint action")
	game.ensure_companion()
	game.party.extra = "hunter"
	game.party.ensure_follower()
	await process_frame
	game.companion.global_position = hero.global_position + Vector2(-20, 0)
	game.party.follower().global_position = hero.global_position + Vector2(20, 0)
	if joint.companions().size() != 2:
		return _fail("Mira and Toren beside the hero")
	var foe := game.spawn_enemy("golem", hero.global_position + Vector2(80, 0))
	var other := game.spawn_enemy("golem", hero.global_position + Vector2(120, 0))
	foe.set_physics_process(false)
	other.set_physics_process(false)
	if not joint.trigger():
		return _fail("G with two companions")
	if foe.blind_time_left <= 0.0 or other.blind_time_left <= 0.0:
		return _fail("Mira's flash blinds foes around the target")
	if foe.slow_time_left <= 0.0:
		return _fail("Toren pins the target")
	# Next blow: flash ×1.6 and pin ×1.4; then pin only, twice more.
	if absf(joint.strike_mult(foe) - 1.6 * 1.4) > 0.001 or absf(joint.strike_mult(foe) - 1.4) > 0.001 or absf(joint.strike_mult(foe) - 1.4) > 0.001 or absf(joint.strike_mult(foe) - 1.0) > 0.001:
		return _fail("the bonuses of the next blows")
	if joint.trigger() or joint.ready_in <= 0.0:
		return _fail("one cooldown")
	if not joint.summary().contains("Звёздная вспышка + Пригвоздить"):
		return _fail("the skill tree names the action: " + joint.summary())
	# Raina: a volley in step with the hero.
	game.party.dismiss(false)
	game.party.extra = "captain_raina"
	game.party.ensure_follower()
	await process_frame
	game.party.follower().global_position = hero.global_position + Vector2(20, 0)
	joint.ready_in = 0.0
	var health := foe.health
	if not joint.trigger() or foe.health >= health:
		return _fail("Raina's volley hits")
	# A companion knocked down does not help.
	game.companion.down_left = 5.0
	game.party.follower().down_left = 5.0
	if not joint.companions().is_empty():
		return _fail("knocked-down companions do not act")
	print("JOINT ACTIONS OK")
	quit()
