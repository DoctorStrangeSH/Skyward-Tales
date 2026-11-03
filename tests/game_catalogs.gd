extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("GAME CATALOG TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var catalogs: GameCatalogs = GameCatalogs.new()
	if not _check(catalogs.spells.has("fireball"), "fireball spell is missing"):
		return
	if not _check(catalogs.spells.has("frostbolt"), "frostbolt spell is missing"):
		return
	if not _check(catalogs.spells.has("chain_lightning"), "chain lightning spell is missing"):
		return
	if not _check(not catalogs.talents.is_empty(), "talent catalog is empty"):
		return
	if not _check(not catalogs.bestiary.is_empty(), "bestiary catalog is empty"):
		return
	print("GAME CATALOGS OK: spells, talents and bestiary loaded")
	quit(0)
