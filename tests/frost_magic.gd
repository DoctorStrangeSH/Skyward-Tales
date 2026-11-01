extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> bool:
	if not value:
		push_error("FROST TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node2D = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.select_spell("frostbolt")
	if not check(game.selected_spell_id == "frostbolt", "Spell selection failed"):
		return
	var starting_mana: int = game.player.mana
	game._cast_spell()
	if not check(game.player.mana == starting_mana - 12, "Frost mana cost wrong"):
		return
	var bolt: MagicBolt = null
	var slime: SlimeEnemy = null
	for child in game.get_children():
		if child is MagicBolt:
			bolt = child
		if child is SlimeEnemy and slime == null:
			slime = child
	if not check(bolt != null and slime != null, "Missing actors"):
		return
	if not check(bolt.spell_id == "frostbolt" and bolt.damage == 10, "Projectile settings wrong"):
		return
	var before: int = slime.health
	bolt._on_body_entered(slime)
	if not check(slime.health == before - 10, "Frost projectile damage wrong"):
		return
	if not check(is_equal_approx(slime.slow_factor, 0.4) and slime.slow_time_left > 2.0, "Frost slow not applied"):
		return
	slime._physics_process(3.0)
	if not check(is_equal_approx(slime.slow_factor, 1.0), "Frost slow did not expire"):
		return
	print("FROST TEST OK: selection, mana, projectile, damage, timed slow")
	quit(0)
