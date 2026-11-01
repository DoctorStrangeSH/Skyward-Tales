extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("DODGE TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	root.add_child(player)
	await process_frame
	if not check(player.start_dodge(), "first dodge should begin"):
		return
	if not check(not player.start_dodge(), "cannot dodge again during active dodge"):
		return
	player.take_damage(25)
	if not check(player.health == 100, "dodge immunity did not prevent damage"):
		return
	player.dodge_time_left = 0.0
	player.take_damage(25)
	if not check(player.health == 75, "damage after dodge was blocked"):
		return
	if not check(not player.start_dodge(), "cooldown must prevent dodge"):
		return
	player.dodge_cooldown_left = 0.0
	if not check(player.start_dodge(), "dodge should be available after cooldown"):
		return
	print("DODGE TEST OK: dodge, invulnerability and cooldown")
	quit(0)
