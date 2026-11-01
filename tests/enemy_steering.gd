extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("STEERING TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.collision_mask = 0
	wall.position = Vector2(130, 100)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 32)
	collider.shape = shape
	wall.add_child(collider)
	root.add_child(wall)
	var enemy: SlimeEnemy = load("res://scripts/enemy.gd").new() as SlimeEnemy
	enemy.position = Vector2(100, 100)
	root.add_child(enemy)
	await physics_frame
	var forward: Vector2 = Vector2.RIGHT
	if not require(enemy._has_world_obstacle(forward, 40.0), "world ray did not detect collision"):
		return
	var direction: Vector2 = enemy._avoid_world_obstacles(forward, 0.016)
	if not require(direction.length_squared() > 0.5 and direction.dot(forward) < 0.95, "steering did not turn around obstacle"):
		return
	if not require(enemy.steering_detour_time > 0.0, "detour was not retained"):
		return
	var repeated: Vector2 = enemy._avoid_world_obstacles(forward, 0.016)
	if not require(repeated.distance_to(direction) < 0.01, "steering direction oscillated during detour"):
		return
	enemy.global_position = Vector2(100, 180)
	await physics_frame
	enemy.steering_detour_time = 0.0
	if not require(enemy._avoid_world_obstacles(forward).distance_to(forward) < 0.01, "clear direct path was not preferred"):
		return
	print("STEERING TEST OK: world collision, sideways detour and stable direction")
	quit(0)
