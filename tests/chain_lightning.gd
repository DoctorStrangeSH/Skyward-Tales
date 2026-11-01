extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, info: String) -> bool:
	if not ok:
		push_error("CHAIN TEST FAILED: " + info)
		quit(1)
		return false
	return true

func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node2D = main_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.select_spell("chain_lightning")
	var mana_before: int = game.player.mana
	game._cast_spell()
	if not check(game.player.mana == mana_before - 18, "Lightning mana cost is wrong"):
		return
	var bolt: MagicBolt = null
	var enemies: Array[SlimeEnemy] = []
	for child in game.get_children():
		if child is MagicBolt:
			bolt = child as MagicBolt
		elif child is SlimeEnemy:
			enemies.append(child as SlimeEnemy)
	if not check(bolt != null and enemies.size() >= 3, "Missing projectile or enemies"):
		return
	if not check(bolt.spell_id == "chain_lightning" and bolt.chain_targets == 2, "Spell configuration not applied"):
		return
	# Place three enemies close together, so the chain must visit each unique target.
	enemies[0].global_position = Vector2(360, 200)
	enemies[1].global_position = Vector2(405, 200)
	enemies[2].global_position = Vector2(450, 200)
	var hp_a: int = enemies[0].health
	var hp_b: int = enemies[1].health
	var hp_c: int = enemies[2].health
	bolt._on_body_entered(enemies[0])
	if not check(enemies[0].health == hp_a - 15, "Primary lightning damage failed"):
		return
	if not check(enemies[1].health == hp_b - 11, "First bounce damage failed"):
		return
	if not check(enemies[2].health == hp_c - 8, "Second bounce damage failed"):
		return
	print("CHAIN TEST OK: selection, mana and 3 distinct damage targets")
	quit(0)
