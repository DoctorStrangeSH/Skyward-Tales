extends SceneTree

## Elemental skill tree: points per level without pausing, prerequisites,
## Sky Seals for ultimates, ultimate effects, save/load and old saves.

var game: SkywardGame

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("SKILL TREE TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _slime(at: Vector2) -> SlimeEnemy:
	var slime := game.spawn_enemy("slime", at)
	slime.max_health = 500
	slime.health = 500
	return slime

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.save_path = "user://skill_tree_test.json"
	var player := game.player

	# Levelling up grants points and never pauses the game.
	player.add_experience(player.experience_to_next)
	await process_frame
	if not _verify(player.level == 2 and not paused and not game.hud.talent_visible, "level up does not pause"):
		return
	if not _verify(SkillTree.available_points(player) == 1, "one point per level"):
		return

	# Prerequisites and points.
	if not _verify(not SkillTree.can_learn(player, "lingering_flame"), "tier 2 needs its tier 1 skill"):
		return
	var base_bonus := player.get_spell_bonus("fireball")
	if not _verify(game.learn_skill("fire_power") and player.get_spell_bonus("fireball") == base_bonus + 3, "Жар boosts fireball"):
		return
	if not _verify(not game.learn_skill("lingering_flame") and game.hud.message_label.text.contains("очков"), "no points left is explained"):
		return
	player.bonus_skill_points = 1
	if not _verify(game.learn_skill("lingering_flame") and player.get_burn_damage_bonus() >= 1, "Тлеющее пламя adds burn damage"):
		return

	# Ultimates need a Sky Seal.
	player.bonus_skill_points += 1
	if not _verify(SkillTree.block_reason(player, "fire_ultimate").contains("Печать"), "ultimate needs a seal"):
		return
	game._grant_sky_seal()
	if not _verify(game.learn_skill("fire_ultimate") and SkillTree.seals(player) == 0, "seal is spent on the ultimate"):
		return

	# The tree window.
	game.hud.toggle_skill_tree(player)
	if not _verify(game.hud.skills_visible and game.hud.skills_view.columns.get_child_count() == 3, "T window shows the three warrior branches"):
		return
	if not _verify(game.hud.skills_view.buttons.has("second_wind") and game.hud.skills_view.buttons.has("blade_mastery"), "warrior skills have buttons"):
		return
	game.hud.skills_view.show_group("mage")
	if not _verify(game.hud.skills_view.buttons.has("fire_ultimate") and not game.hud.skills_view.buttons.has("blade_mastery"), "the mage tab shows the elements"):
		return
	game.hud.toggle_skill_tree(player)

	# Пламя феникса: explosion splashes nearby enemies.
	var target := _slime(Vector2(600, 600))
	var neighbour := _slime(Vector2(620, 600))
	var far := _slime(Vector2(900, 600))
	await process_frame
	var bolt: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate()
	bolt.setup(Vector2.RIGHT, 40)
	bolt.configure_effect("fireball", 1.0, 0.0)
	bolt.configure_burning(3, 2.0)
	bolt.explode_radius = 48.0
	game.add_child(bolt)
	bolt.global_position = Vector2(598, 600)
	bolt._on_body_entered(target)
	if not _verify(neighbour.health < 500 and far.health == 500, "explosion hits neighbours only"):
		return

	# Сердце зимы: frost bolt pierces two extra enemies.
	var frost: MagicBolt = load("res://scenes/magic_bolt.tscn").instantiate()
	frost.setup(Vector2.RIGHT, 10)
	frost.configure_effect("frostbolt", 0.4, 2.5)
	frost.pierce_left = 2
	frost.freeze_on_hit = true
	game.add_child(frost)
	for enemy in [target, neighbour, far]:
		frost._on_body_entered(enemy)
	if not _verify(frost.is_queued_for_deletion() and far.slow_factor <= 0.11, "pierce ends on the third enemy and freezes"):
		return

	# Второе дыхание.
	player.talents["second_wind"] = 1
	player.take_damage(9999)
	if not _verify(player.health > 0 and not game.game_over and player.second_wind_ready_in > 0.0, "second wind saves the hero"):
		return
	player.take_damage(9999)
	if not _verify(player.health <= 0, "second wind has a cooldown"):
		return
	game.get_tree().paused = false
	game.game_over = false
	player.health = player.max_health

	# Save/load and old saves.
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot) and restored.player.has_skill("fire_ultimate") and restored.player.bonus_skill_points == player.bonus_skill_points, "skills survive save/load"):
		return
	snapshot["player"]["talents"] = {"arcane_power": 1}
	snapshot["player"].erase("bonus_skill_points")
	if not _verify(restored.restore_save_snapshot(snapshot) and SkillTree.rank(restored.player, "arcane_power") == 1 and not SkillTree.block_reason(restored.player, "swift_cast").begins_with("Сначала"), "old level-up talents become tree skills and unlock their branch"):
		return
	print("SKILL TREE OK: points, prerequisites, seals, window, ultimates, second wind, saves")
	quit(0)
