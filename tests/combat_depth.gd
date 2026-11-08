extends SceneTree

## Combat feel and elites: lunge telegraph and poses, knockback (bosses
## resist), dissolve ghost on death, screen shake with its setting, elite
## modifiers, guaranteed loot, placed elites and save/load.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("COMBAT DEPTH TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	GameSettings.reload()
	GameSettings.set_bool("screen_shake", true)
	game = load("res://scenes/main.tscn").instantiate()
	game.set("classic_balance", true)
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false

	# Telegraph and squash before a wolf lunge.
	var wolf := game.spawn_enemy("wolf", Vector2(600, 600))
	await process_frame
	wolf._start_special_attack(Vector2.RIGHT)
	if not _verify(wolf.combat_feedback.telegraph_length > 0.0 and wolf.combat_feedback.telegraph_direction == Vector2.RIGHT, "wind-up draws a lunge arrow"):
		return
	for _i in range(8):
		await process_frame
	if not _verify(wolf.visual.scale.x > wolf.visual.scale.y, "wind-up squashes the sprite"):
		return
	wolf._cancel_special_attack()
	if not _verify(wolf.combat_feedback.telegraph_length == 0.0, "cancel clears the arrow"):
		return

	# Knockback; bosses resist.
	wolf.apply_knockback(Vector2.RIGHT, 90.0)
	var start_x := wolf.global_position.x
	for _i in range(6):
		await physics_frame
	if not _verify(wolf.global_position.x > start_x + 2.0, "hits push enemies back"):
		return
	game.quests.states["grove_spirits"]["completed"] = true
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	await process_frame
	var guardian: SlimeEnemy = null
	for node in game.get_children():
		if node is GroveGuardian:
			guardian = node
	guardian.apply_knockback(Vector2.RIGHT, 90.0)
	if not _verify(guardian.knockback == Vector2.ZERO, "bosses resist knockback"):
		return

	# Placed elite: the fierce wolf in the grove.
	var fierce: SlimeEnemy = null
	for node in game.get_children():
		if node is ForestWolf and node.elite_id == "fierce":
			fierce = node
	if not _verify(fierce != null, "the grove has a placed fierce wolf"):
		return
	if not _verify(fierce.combat_feedback.elite_name == "Свирепый" and fierce.attack_damage == 18 and fierce.xp_reward == int(round(48 * SkywardGame.XP_RATE)), "elite modifier changes title, damage and experience"):
		return
	if not _verify(fierce.visual.scale.x > 1.2 and fierce.get_node_or_null("EliteAura") != null, "elites are bigger and glow"):
		return

	# Defeat: ghost, guaranteed loot, shake.
	var before_loot := 0
	for node in game.get_children():
		if node is WorldLoot and str(node.item_id).begins_with("gen_"):
			before_loot += 1
	fierce.take_damage(9999)
	var ghost := false
	for node in game.get_children():
		if node is Sprite2D and node.get_script() == null and node.modulate.r > 1.0:
			ghost = true
	if not _verify(ghost, "defeated enemy leaves a dissolving ghost"):
		return
	var after_loot := 0
	for node in game.get_children():
		if node is WorldLoot and str(node.item_id).begins_with("gen_"):
			after_loot += 1
	if not _verify(after_loot >= before_loot + 1, "elites always drop equipment"):
		return
	if not _verify(game._shake_time > 0.0, "elite defeat shakes the screen"):
		return

	# Shake setting.
	game._shake_time = 0.0
	GameSettings.set_bool("screen_shake", false)
	game.player.take_damage(5)
	if not _verify(game._shake_time == 0.0, "shake can be switched off"):
		return
	GameSettings.set_bool("screen_shake", true)
	game.player.take_damage(5)
	if not _verify(game._shake_time > 0.0, "taking damage shakes the screen"):
		return

	# Elites survive save/load; random elites only in story mode.
	var stone := game.spawn_enemy("slime", Vector2(400, 400), "stone")
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	restored.classic_balance = true
	root.add_child(restored)
	await process_frame
	restored.restore_save_snapshot(snapshot)
	var restored_stone := false
	for node in restored.get_children():
		if node is SlimeEnemy and node.elite_id == "stone" and node.max_health == stone.max_health:
			restored_stone = true
	if not _verify(restored_stone, "elite survives save/load"):
		return
	game.loot_rng.seed = 1
	var rolled := 0
	for _i in range(40):
		if not game.spawn_enemy("slime", Vector2(100, 100), "?").elite_id.is_empty():
			rolled += 1
	if not _verify(rolled == 0, "no random elites outside story mode"):
		return
	game.quests.states["main_prologue"]["started"] = true
	for _i in range(80):
		if not game.spawn_enemy("slime", Vector2(100, 100), "?").elite_id.is_empty():
			rolled += 1
	if not _verify(rolled > 0, "random elites appear in story mode"):
		return
	print("COMBAT DEPTH OK: telegraph, poses, knockback, ghost, shake, elites, saves")
	quit(0)
