extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("SHAMAN TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._set_region("moonlit_grove", Vector2(140, 430), false)
	var shaman: ForestShaman = null
	for child in game.get_children():
		if child is ForestShaman:
			shaman = child
	if not check(shaman != null and shaman.health == 38, "shaman not spawned"):
		return
	shaman._shoot_at(game.player.global_position)
	var orb: EnemyMagicOrb = null
	for child in game.get_children():
		if child is EnemyMagicOrb:
			orb = child
	if not check(orb != null and orb.damage == 9 and orb.collision_mask == 5, "orb configuration wrong"):
		return
	var before: int = game.player.health
	orb._on_body_entered(game.player)
	orb._on_body_entered(game.player)
	if not check(game.player.health == before - 9, "orb must hit player only once"):
		return
	var data: Dictionary = game.make_save_snapshot()
	var found: bool = false
	for enemy_data in data["world"]["enemies"]:
		if enemy_data["kind"] == "shaman":
			found = true
	if not check(found, "save did not preserve shaman kind"):
		return
	print("SHAMAN TEST OK: spawn, enemy projectile, single hit, save type")
	quit(0)
