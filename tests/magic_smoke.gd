extends SceneTree

## Headless integration test: casting through the actual _input handler and dealing damage.
## Executed after project import by GitHub Actions, with Godot 4.7.2.

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, explanation: String) -> bool:
	if not condition:
		push_error("MAGIC TEST FAILED: " + explanation)
		quit(1)
		return false
	return true

func _run() -> void:
	var game_scene: PackedScene = load("res://scenes/main.tscn")
	if not _require(game_scene != null, "Main scene not found"):
		return
	var game: Node2D = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	var player: PlayerCharacter = game.get("player") as PlayerCharacter
	if not _require(player != null, "Player not spawned"):
		return
	if not _require(player.mana == player.max_mana, "Player mana not initialized"):
		return

	var test_direction: Vector2 = Vector2.RIGHT
	var directional: DirectionalSprite = player.visual
	if not _require(directional != null and directional.texture != null, "Hero directional texture missing"):
		return
	var vectors: Array[Vector2] = [
		Vector2.DOWN, Vector2(1, 1), Vector2.RIGHT, Vector2(1, -1),
		Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1)
	]
	for index in range(vectors.size()):
		directional.set_direction_vector(vectors[index])
		if not _require(directional.direction_index == index, "Wrong 8-way row %d" % index):
			return

	# Deliver a real right click (spells; the left button is the sword).
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = Vector2(300, 180)
	var initial_mana: int = player.mana
	game._input(click)
	if not _require(player.mana < initial_mana, "RMB did not consume mana"):
		return

	var bolt: MagicBolt = null
	for child in game.get_children():
		if child is MagicBolt:
			bolt = child as MagicBolt
			break
	if not _require(bolt != null, "LMB did not spawn projectile"):
		return
	if not _require(bolt.visual != null and bolt.visual.texture != null, "Projectile texture missing"):
		return
	if not _require(bolt.damage > 0, "Projectile damage is zero"):
		return

	# Test the collision callback against a real enemy instance.
	var slime: SlimeEnemy = null
	for child in game.get_children():
		if child is SlimeEnemy:
			slime = child as SlimeEnemy
			break
	if not _require(slime != null, "Slime not spawned"):
		return
	if not _require(slime.visual != null and slime.visual.texture != null, "Slime texture missing"):
		return
	var hp_before: int = slime.health
	bolt._on_body_entered(slime)
	if not _require(slime.health == hp_before - bolt.damage, "Projectile collision does not damage slime"):
		return

	print("MAGIC TEST OK: RMB cast, mana, projectile, 8 directions, collision damage")
	quit(0)
