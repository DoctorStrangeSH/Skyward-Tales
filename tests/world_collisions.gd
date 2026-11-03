extends SceneTree

## Collision regression test for Godot 4.7.
func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("WORLD TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node2D = scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var world: Node2D = main.get_node("World")
	var barriers: int = 0
	for node in world.get_children():
		if node is StaticBody2D and node.collision_layer == 4:
			barriers += 1
	if not _check(barriers >= 22, "Expected trees, ruins, pond and perimeter collision"):
		return
	var player: PlayerCharacter = main.player
	if not _check((player.collision_mask & 4) != 0, "Player ignores obstacles"):
		return
	var enemy: SlimeEnemy = null
	for node in main.get_children():
		if node is SlimeEnemy:
			enemy = node
			break
	if not _check(enemy != null and (enemy.collision_mask & 4) != 0, "Enemies ignore obstacles"):
		return
	var projectile_scene: PackedScene = load("res://scenes/magic_bolt.tscn")
	var projectile: MagicBolt = projectile_scene.instantiate()
	root.add_child(projectile)
	if not _check((projectile.collision_mask & 4) != 0, "Fireball ignores obstacles"):
		return
	print("WORLD TEST OK: solid world collisions, boundaries and masks")
	quit(0)
