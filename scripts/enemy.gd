extends CharacterBody2D
class_name SlimeEnemy

signal defeated(xp_reward: int)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const FEEDBACK_SCRIPT := preload("res://scripts/enemy_combat_feedback.gd")
const SLIME_SHEET := "res://assets/sprites/enemies/forest_slime_true8.png"
const FIRESTORM_SPREAD_RADIUS := 64.0
const FIRESTORM_SPREAD_DURATION := 1.0
const FIRESTORM_REACTION_COOLDOWN := 0.75
const FIRESTORM_BONUS_DAMAGE := 4

@export var max_health: int = 32
@export var move_speed: float = 38.0
@export var xp_reward: int = 14

var health: int
var attack_cooldown: float = 0.0
var slow_time_left: float = 0.0
var slow_factor: float = 1.0
var burn_time_left: float = 0.0
var burn_tick_interval: float = 0.5
var burn_tick_timer: float = 0.0
var burn_damage: int = 0
var firestorm_cooldown_left: float = 0.0
var elemental_multipliers: Dictionary = {}
var visual: DirectionalSprite
var combat_feedback: EnemyCombatFeedback

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
	combat_feedback = FEEDBACK_SCRIPT.new() as EnemyCombatFeedback
	combat_feedback.set_health(health, max_health)
	add_child(combat_feedback)

enum BrainState { IDLE, CHASE, RETURN, RETREAT }

@export var detection_radius: float = 180.0
@export var give_up_radius: float = 270.0
@export var return_tolerance: float = 6.0
@export var retreat_health_ratio: float = 0.25
@export var leash_distance: float = 320.0

## Configurable melee attack values. Zero windup/lunge keeps the classic contact attack.
enum AttackState { NONE, WINDUP, LUNGE }
@export var attack_damage: int = 7
@export var attack_range: float = 18.0
@export var attack_cooldown_duration: float = 1.1
@export var attack_windup_duration: float = 0.0
@export var attack_lunge_duration: float = 0.0
@export var attack_lunge_speed: float = 0.0
@export var attack_hit_radius: float = 18.0
@export var base_visual_tint: Color = Color.WHITE
var attack_state: AttackState = AttackState.NONE
var attack_timer: float = 0.0
var attack_direction: Vector2 = Vector2.ZERO
var attack_has_hit: bool = false

var home_position: Vector2
var brain_state: BrainState = BrainState.IDLE
var steering_side: int = 1
var steering_detour_time: float = 0.0
var steering_detour_direction: Vector2 = Vector2.ZERO

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

func _has_world_obstacle(direction: Vector2, distance: float) -> bool:
	if direction.length_squared() < 0.0001:
		return false
	var origin: Vector2 = global_position
	var query := PhysicsRayQueryParameters2D.create(origin, origin + direction.normalized() * distance, 4)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _avoid_world_obstacles(desired: Vector2, delta: float = 0.016) -> Vector2:
	if desired.length_squared() < 0.0001:
		steering_detour_time = 0.0
		return Vector2.ZERO
	var forward: Vector2 = desired.normalized()
	# Maintain a detour direction briefly to avoid oscillating at the same tree corner.
	if steering_detour_time > 0.0:
		steering_detour_time = maxf(0.0, steering_detour_time - delta)
		if not _has_world_obstacle(steering_detour_direction, 22.0):
			return steering_detour_direction
		steering_detour_time = 0.0
	if not _has_world_obstacle(forward, 26.0):
		return forward
	# Prefer wide lateral clearance, then try intermediate angles.
	for angle in [PI * 0.5, PI * 0.35, PI * 0.75]:
		for side in [steering_side, -steering_side]:
			var candidate: Vector2 = forward.rotated(float(side) * angle)
			if not _has_world_obstacle(candidate, 32.0):
				steering_side = side
				steering_detour_direction = candidate
				steering_detour_time = 0.35
				return candidate
	# Do not push into a solid obstacle if neither side is safe.
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	_update_burning(delta)
	_refresh_elemental_feedback()
	if is_queued_for_deletion():
		return
	slow_time_left = maxf(0.0, slow_time_left - delta)
	if slow_time_left <= 0.0:
		slow_factor = 1.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.is_physics_processing():
		_cancel_special_attack()
		velocity = Vector2.ZERO
		visual.set_moving(false)
		return
	var offset: Vector2 = player.global_position - global_position
	var distance_to_player: float = offset.length()
	_choose_state(distance_to_player)
	if _update_special_attack(delta, player):
		return
	var desired: Vector2 = Vector2.ZERO
	match brain_state:
		BrainState.CHASE:
			if distance_to_player > attack_range:
				desired = offset.normalized()
			elif attack_cooldown <= 0.0 and player.has_method("take_damage"):
				if attack_windup_duration > 0.0 or attack_lunge_duration > 0.0:
					_start_special_attack(offset.normalized())
				else:
					player.take_damage(attack_damage)
					attack_cooldown = attack_cooldown_duration
		BrainState.RETREAT:
			desired = -offset.normalized() if distance_to_player < give_up_radius else Vector2.ZERO
		BrainState.RETURN:
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

func _start_special_attack(direction: Vector2) -> void:
	attack_direction = direction.normalized()
	attack_has_hit = false
	attack_state = AttackState.WINDUP if attack_windup_duration > 0.0 else AttackState.LUNGE
	attack_timer = attack_windup_duration if attack_state == AttackState.WINDUP else attack_lunge_duration
	velocity = Vector2.ZERO
	visual.set_moving(false)
	visual.modulate = Color(1.0, 0.58, 0.34) if attack_state == AttackState.WINDUP else Color(1.0, 0.88, 0.62)
	combat_feedback.set_warning(attack_state == AttackState.WINDUP)

func _cancel_special_attack() -> void:
	attack_state = AttackState.NONE
	attack_timer = 0.0
	attack_has_hit = false
	if combat_feedback != null:
		combat_feedback.set_warning(false)
	if visual != null:
		visual.modulate = base_visual_tint

func _update_special_attack(delta: float, player: Node2D) -> bool:
	if attack_state == AttackState.NONE:
		return false
	if brain_state != BrainState.CHASE:
		_cancel_special_attack()
		return false
	if attack_state == AttackState.WINDUP:
		attack_timer = maxf(0.0, attack_timer - delta)
		velocity = Vector2.ZERO
		visual.set_moving(false)
		if attack_timer <= 0.0:
			attack_state = AttackState.LUNGE
			combat_feedback.set_warning(false)
			attack_timer = attack_lunge_duration
			visual.modulate = Color(1.0, 0.88, 0.62)
		return true
	if attack_state == AttackState.LUNGE:
		velocity = attack_direction * attack_lunge_speed * slow_factor
		visual.set_direction_vector(attack_direction)
		visual.set_moving(true)
		move_and_slide()
		if not attack_has_hit and player.has_method("take_damage") and global_position.distance_to(player.global_position) <= attack_hit_radius:
			player.take_damage(attack_damage)
			attack_has_hit = true
		attack_timer = maxf(0.0, attack_timer - delta)
		if attack_timer <= 0.0:
			attack_state = AttackState.NONE
			attack_cooldown = attack_cooldown_duration
			velocity = Vector2.ZERO
			visual.set_moving(false)
			visual.modulate = base_visual_tint
		return true
	return false

func _refresh_elemental_feedback() -> void:
	if combat_feedback != null:
		combat_feedback.set_statuses(burn_time_left > 0.0, slow_time_left > 0.0)

func take_elemental_damage(amount: int, element: String) -> void:
	var multiplier: float = clampf(float(elemental_multipliers.get(element, 1.0)), 0.25, 2.0)
	take_damage(maxi(1, int(round(float(amount) * multiplier))))

func get_status_duration_multiplier(element: String) -> float:
	return clampf(float(elemental_multipliers.get(element, 1.0)), 0.25, 2.0)

func apply_burning(damage_per_tick: int, duration: float) -> void:
	if health <= 0 or duration <= 0.0 or damage_per_tick <= 0:
		return
	# Repeated hits refresh the effect rather than stacking hidden damage instances.
	burn_damage = maxi(burn_damage, damage_per_tick)
	burn_time_left = maxf(burn_time_left, duration * get_status_duration_multiplier("fire"))
	if burn_tick_timer <= 0.0:
		burn_tick_timer = burn_tick_interval
	_refresh_elemental_feedback()

func _update_burning(delta: float) -> void:
	firestorm_cooldown_left = maxf(0.0, firestorm_cooldown_left - maxf(delta, 0.0))
	if burn_time_left <= 0.0 or health <= 0:
		return
	var elapsed: float = minf(maxf(delta, 0.0), burn_time_left)
	burn_time_left = maxf(0.0, burn_time_left - elapsed)
	burn_tick_timer -= elapsed
	while burn_tick_timer <= 0.0 and health > 0:
		take_elemental_damage(burn_damage, "fire")
		burn_tick_timer += burn_tick_interval
		if is_queued_for_deletion():
			break
	if burn_time_left <= 0.0:
		burn_damage = 0
		burn_tick_timer = 0.0
	_refresh_elemental_feedback()

func _spread_firestorm_burning(damage_per_tick: int, duration: float) -> void:
	if damage_per_tick <= 0 or duration <= 0.0:
		return
	var radius_squared: float = FIRESTORM_SPREAD_RADIUS * FIRESTORM_SPREAD_RADIUS
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var nearby := candidate as Node2D
		if nearby == null or nearby == self or nearby.is_queued_for_deletion():
			continue
		if not nearby.has_method("apply_burning"):
			continue
		if global_position.distance_squared_to(nearby.global_position) > radius_squared:
			continue
		nearby.apply_burning(damage_per_tick, duration)

func react_to_spell(spell_id: String) -> int:
	# Elemental reactions resolve after the direct hit and before the next status is applied.
	var bonus_damage: int = 0
	if spell_id == "frostbolt" and burn_time_left > 0.0:
		burn_time_left = 0.0
		burn_tick_timer = 0.0
		burn_damage = 0
		if combat_feedback != null:
			combat_feedback.show_reaction("ПАР!")
		take_elemental_damage(8, "ice")
		bonus_damage += 8

	if spell_id == "chain_lightning":
		if slow_time_left > 0.0:
			slow_time_left = 0.0
			slow_factor = 1.0
			if combat_feedback != null:
				combat_feedback.show_reaction("РАЗРЯД!")
			take_elemental_damage(6, "lightning")
			bonus_damage += 6
		if health > 0 and burn_time_left > 0.0 and firestorm_cooldown_left <= 0.0:
			# Firestorm keeps the original burn on its source, but spreads a weaker version.
			var spread_damage: int = maxi(1, int(ceil(float(burn_damage) * 0.5)))
			var spread_duration: float = minf(burn_time_left, FIRESTORM_SPREAD_DURATION)
			firestorm_cooldown_left = FIRESTORM_REACTION_COOLDOWN
			_spread_firestorm_burning(spread_damage, spread_duration)
			if combat_feedback != null:
				combat_feedback.show_reaction("ОГНЕННАЯ БУРЯ!")
			take_elemental_damage(FIRESTORM_BONUS_DAMAGE, "lightning")
			bonus_damage += FIRESTORM_BONUS_DAMAGE

	if bonus_damage > 0:
		_refresh_elemental_feedback()
	return bonus_damage

func apply_slow(multiplier: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(multiplier, 0.1, 1.0))
	slow_time_left = maxf(slow_time_left, duration * get_status_duration_multiplier("ice"))
	_refresh_elemental_feedback()

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	if combat_feedback != null:
		combat_feedback.set_health(health, max_health)
		combat_feedback.show_damage(amount)
	if health <= 0:
		defeated.emit(xp_reward)
		queue_free()
