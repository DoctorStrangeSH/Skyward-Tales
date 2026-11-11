extends "res://scripts/enemy.gd"
class_name ForestShaman

const ORB_SCRIPT := preload("res://scripts/enemy_magic_orb.gd")
@export var preferred_distance: float = 145.0
@export var retreat_distance: float = 90.0
@export var shooting_distance: float = 240.0
## Support: every WARD_EVERY seconds the shaman wards the nearest fighting
## ally within WARD_RANGE (two blows glance off it). Kill the shaman first.
const WARD_EVERY := 7.0
const WARD_RANGE := 150.0
var ward_cooldown: float = 2.5

## The nearest ally without a ward (not a shaman).
func ward_target() -> SlimeEnemy:
	var best: SlimeEnemy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is SlimeEnemy) or node is ForestShaman or node.is_queued_for_deletion():
			continue
		var ally := node as SlimeEnemy
		if ally.health <= 0 or ally.ward_hits > 0 or not ally.visible:
			continue
		var distance := ally.global_position.distance_to(global_position)
		if distance <= WARD_RANGE and (best == null or distance < best.global_position.distance_to(global_position)):
			best = ally
	return best

func cast_ward() -> bool:
	var ally := ward_target()
	if ally == null:
		return false
	ally.receive_ward(2)
	ward_cooldown = WARD_EVERY
	Vfx.flash(visual, Color(0.6, 1.0, 0.8), 0.3)
	_pose("lunge")
	combat_feedback.show_reaction("ОБЕРЕГАЕТ")
	GameAudio.play("pickup", -6.0, -0.2)
	var arena := get_parent()
	if arena != null and arena.has_method("_streak"):
		arena._streak(global_position + Vector2(0, -10), ally.global_position + Vector2(0, -8), Color(0.5, 1.0, 0.6, 0.8), 2.0)
	return true

func _ready() -> void:
	max_health = 38
	move_speed = 35.0
	xp_reward = 28
	detection_radius = 250.0
	give_up_radius = 320.0
	retreat_health_ratio = 0.0
	elemental_multipliers = {"fire": 0.75, "lightning": 1.3}
	if sprite_sheet == SLIME_SHEET:
		sprite_sheet = "res://assets/sprites/enemies/forest_shaman_8dir.png"
		sprite_fps = 6.0
	attack_cooldown_duration = 1.7
	super._ready()

func _physics_process(delta: float) -> void:
	_apply_knockback(delta)
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
	ward_cooldown = maxf(0.0, ward_cooldown - delta)
	if brain_state == BrainState.CHASE:
		if ward_cooldown <= 0.0 and not cast_ward():
			ward_cooldown = 1.0
		if distance < retreat_distance:
			desired = -to_player.normalized()
		elif distance > preferred_distance:
			desired = to_player.normalized()
		if distance <= shooting_distance and attack_cooldown <= 0.0:
			if not _has_world_obstacle(to_player, distance):
				# A green flash and a crouch telegraph each spell.
				Vfx.flash(visual, Color(0.6, 1.0, 0.8), 0.25)
				_pose("lunge")
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
