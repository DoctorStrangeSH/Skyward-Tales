extends "res://scripts/enemy.gd"
class_name ForestShaman

const ORB_SCRIPT := preload("res://scripts/enemy_magic_orb.gd")
@export var preferred_distance: float = 145.0
@export var retreat_distance: float = 90.0
@export var shooting_distance: float = 240.0

func _ready() -> void:
	max_health = 38
	move_speed = 35.0
	xp_reward = 28
	detection_radius = 250.0
	give_up_radius = 320.0
	retreat_health_ratio = 0.0
	elemental_multipliers = {"fire": 0.75, "lightning": 1.3}
	base_visual_tint = Color(0.55, 0.95, 0.66)
	attack_cooldown_duration = 1.7
	super._ready()

func _physics_process(delta: float) -> void:
	_update_burning(delta)
	if is_queued_for_deletion():
		return
	slow_time_left = maxf(0.0, slow_time_left - delta)
	_refresh_elemental_feedback()
	if slow_time_left <= 0.0:
		slow_factor = 1.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.is_physics_processing():
		velocity = Vector2.ZERO
		visual.set_moving(false)
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	_choose_state(distance)
	var desired: Vector2 = Vector2.ZERO
	if brain_state == BrainState.CHASE:
		if distance < retreat_distance:
			desired = -to_player.normalized()
		elif distance > preferred_distance:
			desired = to_player.normalized()
		if distance <= shooting_distance and attack_cooldown <= 0.0:
			if not _has_world_obstacle(to_player, distance):
				_shoot_at(player.global_position)
				attack_cooldown = attack_cooldown_duration
	elif brain_state == BrainState.RETURN:
		var home_offset: Vector2 = home_position - global_position
		if home_offset.length() <= return_tolerance:
			brain_state = BrainState.IDLE
		else:
			desired = home_offset.normalized()
	if desired.length_squared() > 0.001:
		var steered: Vector2 = _avoid_world_obstacles(desired, delta)
		velocity = steered * move_speed * slow_factor
		visual.set_direction_vector(steered if steered.length_squared() > 0.01 else desired)
		visual.set_moving(steered.length_squared() > 0.01)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		visual.set_moving(false)

func _shoot_at(target_position: Vector2) -> void:
	var orb := ORB_SCRIPT.new() as EnemyMagicOrb
	orb.setup(target_position - global_position, 9)
	orb.position = global_position
	get_parent().add_child(orb)
