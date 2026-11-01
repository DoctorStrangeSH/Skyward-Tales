extends CharacterBody2D
class_name SlimeEnemy

signal defeated(xp_reward: int)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const SLIME_SHEET := "res://assets/sprites/enemies/forest_slime_true8.png"

@export var max_health: int = 32
@export var move_speed: float = 38.0
@export var xp_reward: int = 14

var health: int
var attack_cooldown: float = 0.0
var slow_time_left: float = 0.0
var slow_factor: float = 1.0
var visual: DirectionalSprite

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 5
	health = max_health
	home_position = global_position
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	shape_node.shape = shape
	add_child(shape_node)
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(SLIME_SHEET, 4, 8, 1.5, 5.5)
	visual.offset = Vector2(0.0, -14.0)
	visual.set_direction_vector(Vector2.DOWN)
	visual.modulate = base_visual_tint
	add_child(visual)

enum BrainState { IDLE, CHASE, RETURN, RETREAT }

@export var detection_radius: float = 180.0
@export var give_up_radius: float = 270.0
@export var return_tolerance: float = 6.0
@export var retreat_health_ratio: float = 0.25
@export var leash_distance: float = 320.0

var home_position: Vector2
var brain_state: BrainState = BrainState.IDLE
var steering_side: int = 1

func _choose_state(distance_to_player: float) -> void:
	if brain_state == BrainState.RETREAT:
		# After escaping, recover the original patrol position.
		if distance_to_player > give_up_radius:
			brain_state = BrainState.RETURN
	elif brain_state == BrainState.CHASE:
		if health <= int(ceil(float(max_health) * retreat_health_ratio)):
			brain_state = BrainState.RETREAT
		elif distance_to_player > give_up_radius or global_position.distance_to(home_position) > leash_distance:
			brain_state = BrainState.RETURN
	elif brain_state == BrainState.IDLE or brain_state == BrainState.RETURN:
		if distance_to_player < detection_radius and health > int(ceil(float(max_health) * retreat_health_ratio)):
			brain_state = BrainState.CHASE
		elif brain_state == BrainState.IDLE and global_position.distance_to(home_position) > return_tolerance:
			brain_state = BrainState.RETURN

func _avoid_world_obstacles(desired: Vector2) -> Vector2:
	if desired.length_squared() < 0.0001:
		return desired
	# Query only the static world layer so the slime doesn't steer around its prey.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var forward: Vector2 = desired.normalized()
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + forward * 24.0, 4)
	ray.exclude = [get_rid()]
	if space.intersect_ray(ray).is_empty():
		return forward
	# Slide around a blocked path by trying two diagonals (rather than pushing into walls).
	for side in [steering_side, -steering_side]:
		var candidate: Vector2 = forward.rotated(float(side) * PI / 2.5)
		var probe := PhysicsRayQueryParameters2D.create(global_position, global_position + candidate * 26.0, 4)
		probe.exclude = [get_rid()]
		if space.intersect_ray(probe).is_empty():
			steering_side = side
			return candidate
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	slow_time_left = maxf(0.0, slow_time_left - delta)
	if slow_time_left <= 0.0:
		slow_factor = 1.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.is_physics_processing():
		velocity = Vector2.ZERO
		visual.set_moving(false)
		return
	var offset: Vector2 = player.global_position - global_position
	var distance_to_player: float = offset.length()
	_choose_state(distance_to_player)
	var desired: Vector2 = Vector2.ZERO
	match brain_state:
		BrainState.CHASE:
			if distance_to_player > 18.0:
				desired = offset.normalized()
			elif attack_cooldown <= 0.0 and player.has_method("take_damage"):
				player.take_damage(7)
				attack_cooldown = 1.1
		BrainState.RETREAT:
			desired = -offset.normalized() if distance_to_player < give_up_radius else Vector2.ZERO
		BrainState.RETURN:
			var home_offset: Vector2 = home_position - global_position
			if home_offset.length() <= return_tolerance:
				brain_state = BrainState.IDLE
			else:
				desired = home_offset.normalized()
	if desired.length_squared() > 0.001:
		var steered: Vector2 = _avoid_world_obstacles(desired)
		velocity = steered * move_speed * slow_factor
		visual.set_direction_vector(steered if steered.length_squared() > 0.01 else desired)
		visual.set_moving(steered.length_squared() > 0.01)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		visual.set_moving(false)

func apply_slow(multiplier: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(multiplier, 0.1, 1.0))
	slow_time_left = maxf(slow_time_left, duration)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		defeated.emit(xp_reward)
		queue_free()
