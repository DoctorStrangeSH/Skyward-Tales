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
## Elemental combos (see react_to_spell / react_to_melee):
## shocked by lightning, blinded by steam (cannot attack).
var shock_time_left: float = 0.0
var blind_time_left: float = 0.0
var firestorm_cooldown_left: float = 0.0
var elemental_multipliers: Dictionary = {}
var visual: DirectionalSprite
## Subclasses pick their own atlas before calling super._ready().
var sprite_sheet: String = SLIME_SHEET
const CHIBI_ENEMIES := {
	"res://assets/sprites/enemies/forest_shaman_8dir.png": "shaman",
	"res://assets/sprites/enemies/rift_shade_8dir.png": "shade",
}
var sprite_scale: float = 1.0
var sprite_offset: Vector2 = Vector2(0.0, -14.0)
var sprite_fps: float = 5.5
## Pushed back by hits; decays quickly. Bosses resist it.
var knockback: Vector2 = Vector2.ZERO
var knockback_resist: float = 0.0
## Elite modifier id from data/elites.json ("" = ordinary enemy).
var elite_id: String = ""
var _pose_tween: Tween
var combat_feedback: EnemyCombatFeedback

## Shielded bosses ignore damage (Этап 18, BossMechanics).
var invulnerable: bool = false
## Spirits and casters hit with magic: the hero's magic defence counts.
var magic_attacks: bool = false

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
	visual.configure(sprite_sheet, 4, 8, sprite_scale, sprite_fps)
	visual.offset = sprite_offset
	# Humanoid enemies use the pack-style chibi sheets when they are built.
	var chibi := str(CHIBI_ENEMIES.get(sprite_sheet, ""))
	if not chibi.is_empty():
		visual.configure_chibi(chibi, 8.0, sprite_scale)
	visual.set_direction_vector(Vector2.DOWN)
	visual.modulate = base_visual_tint
	Vfx.enable_flash(visual)
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

## Pathfinding (tech debt): when a wall stands between the foe and its goal,
## it follows the navigation mesh of the land; otherwise it goes straight.
const NAV_REFRESH := 0.4
var _nav_path: PackedVector2Array = PackedVector2Array()
var _nav_clock: float = 0.0
var _nav_goal: Vector2 = Vector2.INF

func _line_blocked(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target, 4)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _nav_direction(target: Vector2, fallback: Vector2, delta: float) -> Vector2:
	_nav_clock -= delta
	if _nav_clock <= 0.0 or target.distance_to(_nav_goal) > 24.0:
		_nav_clock = NAV_REFRESH
		_nav_goal = target
		_nav_path = PackedVector2Array()
		if _line_blocked(target):
			var nav_map := get_world_2d().navigation_map
			if NavigationServer2D.map_get_iteration_id(nav_map) > 0:
				_nav_path = NavigationServer2D.map_get_path(nav_map, global_position, target, true)
	while _nav_path.size() > 0 and global_position.distance_to(_nav_path[0]) < 8.0:
		_nav_path.remove_at(0)
	if _nav_path.is_empty():
		return fallback
	return (_nav_path[0] - global_position).normalized()

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
	_apply_knockback(delta)
	_update_burning(delta)
	_refresh_elemental_feedback()
	if is_queued_for_deletion():
		return
	slow_time_left = maxf(0.0, slow_time_left - delta)
	if slow_time_left <= 0.0:
		slow_factor = 1.0
	shock_time_left = maxf(0.0, shock_time_left - delta)
	blind_time_left = maxf(0.0, blind_time_left - delta)
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
				desired = _shape_chase(_nav_direction(player.global_position, offset.normalized(), delta), delta)
			elif attack_cooldown <= 0.0 and blind_time_left <= 0.0 and player.has_method("take_damage"):
				if attack_windup_duration > 0.0 or attack_lunge_duration > 0.0:
					_start_special_attack(offset.normalized())
				else:
					player.take_damage(attack_damage, self)
					attack_cooldown = attack_cooldown_duration
		BrainState.RETREAT:
			desired = -offset.normalized() if distance_to_player < give_up_radius else Vector2.ZERO
		BrainState.RETURN:
			var home_offset: Vector2 = home_position - global_position
			if home_offset.length() <= return_tolerance:
				brain_state = BrainState.IDLE
			else:
				desired = _nav_direction(home_position, home_offset.normalized(), delta)
	if desired.length_squared() > 0.001:
		var steered: Vector2 = _avoid_world_obstacles(desired, delta)
		velocity = steered * move_speed * slow_factor
		visual.set_direction_vector(steered if steered.length_squared() > 0.01 else desired)
		visual.set_moving(steered.length_squared() > 0.01)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		visual.set_moving(false)

## Hook for subclasses to bend the chase direction (bats zig-zag).
func _shape_chase(direction: Vector2, _delta: float) -> Vector2:
	return direction

## Squash/stretch poses: "windup" crouches, "lunge" stretches, "rest" resets.
func _pose(kind: String, duration: float = 0.12) -> void:
	if visual == null or not visual.is_inside_tree():
		return
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	var base := Vector2.ONE * sprite_scale
	var target := base
	match kind:
		"windup":
			target = Vector2(base.x * 1.22, base.y * 0.78)
		"lunge":
			target = Vector2(base.x * 0.82, base.y * 1.2)
	_pose_tween = visual.create_tween()
	_pose_tween.tween_property(visual, "scale", target, duration)
	if kind == "lunge":
		_pose_tween.tween_property(visual, "scale", base, 0.18)

func apply_knockback(direction: Vector2, strength: float) -> void:
	knockback += direction.normalized() * strength * (1.0 - clampf(knockback_resist, 0.0, 1.0))

func _apply_knockback(delta: float) -> void:
	if knockback.length_squared() < 1.0:
		knockback = Vector2.ZERO
		return
	move_and_collide(knockback * delta)
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)

func _start_special_attack(direction: Vector2) -> void:
	attack_direction = direction.normalized()
	attack_has_hit = false
	attack_state = AttackState.WINDUP if attack_windup_duration > 0.0 else AttackState.LUNGE
	attack_timer = attack_windup_duration if attack_state == AttackState.WINDUP else attack_lunge_duration
	velocity = Vector2.ZERO
	visual.set_moving(false)
	visual.modulate = Color(1.0, 0.58, 0.34) if attack_state == AttackState.WINDUP else Color(1.0, 0.88, 0.62)
	combat_feedback.set_warning(attack_state == AttackState.WINDUP)
	if attack_state == AttackState.WINDUP:
		_pose("windup", attack_windup_duration)
		combat_feedback.set_telegraph(attack_direction, attack_lunge_speed * attack_lunge_duration)
	else:
		_pose("lunge")

func _cancel_special_attack() -> void:
	attack_state = AttackState.NONE
	attack_timer = 0.0
	attack_has_hit = false
	if combat_feedback != null:
		combat_feedback.set_warning(false)
		combat_feedback.set_telegraph(Vector2.ZERO, 0.0)
	if visual != null:
		visual.modulate = base_visual_tint
		_pose("rest")

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
			combat_feedback.set_telegraph(Vector2.ZERO, 0.0)
			_pose("lunge")
			attack_timer = attack_lunge_duration
			visual.modulate = Color(1.0, 0.88, 0.62)
		return true
	if attack_state == AttackState.LUNGE:
		velocity = attack_direction * attack_lunge_speed * slow_factor
		visual.set_direction_vector(attack_direction)
		visual.set_moving(true)
		move_and_slide()
		if not attack_has_hit and player.has_method("take_damage") and global_position.distance_to(player.global_position) <= attack_hit_radius:
			player.take_damage(attack_damage, self)
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
		combat_feedback.set_statuses(burn_time_left > 0.0, slow_time_left > 0.0, shock_time_left > 0.0, blind_time_left > 0.0)

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

## Combo strength grows with the hero.
func _reaction_power() -> float:
	var arena := get_parent()
	var hero: Variant = arena.get("player") if arena != null else null
	return 1.0 + 0.1 * float(hero.level - 1) if hero != null else 1.0

func _announce_reaction(reaction_id: String, label: String) -> void:
	if combat_feedback != null:
		combat_feedback.show_reaction(label)
	var arena := get_parent()
	if arena != null and arena.has_method("on_reaction"):
		arena.on_reaction(reaction_id, global_position)

func _enemies_near(radius: float) -> Array:
	var result: Array = []
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var other := candidate as Node2D
		if other == null or other == self or other.is_queued_for_deletion():
			continue
		if global_position.distance_to(other.global_position) <= radius:
			result.append(other)
	return result

func apply_shock(duration: float) -> void:
	shock_time_left = maxf(shock_time_left, duration * get_status_duration_multiplier("lightning"))
	_refresh_elemental_feedback()

func apply_blind(duration: float) -> void:
	blind_time_left = maxf(blind_time_left, duration)
	_refresh_elemental_feedback()

func react_to_spell(spell_id: String) -> int:
	# Elemental reactions resolve after the direct hit and before the next status is applied.
	var bonus_damage: int = 0
	var power := _reaction_power()
	if spell_id == "frostbolt" and burn_time_left > 0.0:
		# Steam: a cloud that blinds and slows everyone around.
		burn_time_left = 0.0
		burn_tick_timer = 0.0
		burn_damage = 0
		_announce_reaction("steam", "ПАР!")
		var steam := roundi(8 * power)
		take_elemental_damage(steam, "ice")
		bonus_damage += steam
		for other in _enemies_near(56.0) + [self]:
			if is_instance_valid(other) and other.has_method("apply_blind"):
				other.apply_blind(2.0)
				other.apply_slow(0.5, 2.0)

	if spell_id == "fireball" and shock_time_left > 0.0:
		# Overload: the charge bursts into a fiery blast.
		shock_time_left = 0.0
		_announce_reaction("overload", "ПЕРЕГРУЗКА!")
		var blast := roundi(10 * power)
		for other in _enemies_near(52.0):
			if other.has_method("take_elemental_damage"):
				other.take_elemental_damage(blast, "fire")
				if is_instance_valid(other) and other.has_method("apply_knockback"):
					other.apply_knockback((other.global_position - global_position).normalized(), 140.0)
		take_elemental_damage(blast, "fire")
		bonus_damage += blast

	if spell_id == "chain_lightning":
		if slow_time_left > 0.0:
			# Crystal chain: the frost conducts lightning to every chilled foe nearby.
			slow_time_left = 0.0
			slow_factor = 1.0
			_announce_reaction("crystal", "КРИСТАЛЬНАЯ ЦЕПЬ!")
			var crack := roundi(7 * power)
			take_elemental_damage(crack, "lightning")
			bonus_damage += crack
			for other in _enemies_near(120.0):
				if other.get("slow_time_left") != null and float(other.slow_time_left) > 0.0:
					other.take_elemental_damage(crack, "lightning")
		if health > 0 and burn_time_left > 0.0 and firestorm_cooldown_left <= 0.0:
			# Firestorm keeps the original burn on its source, but spreads a weaker version.
			var spread_damage: int = maxi(1, int(ceil(float(burn_damage) * 0.5)))
			var spread_duration: float = minf(burn_time_left, FIRESTORM_SPREAD_DURATION)
			firestorm_cooldown_left = FIRESTORM_REACTION_COOLDOWN
			_spread_firestorm_burning(spread_damage, spread_duration)
			_announce_reaction("firestorm", "ОГНЕННАЯ БУРЯ!")
			take_elemental_damage(FIRESTORM_BONUS_DAMAGE, "lightning")
			bonus_damage += FIRESTORM_BONUS_DAMAGE

	if spell_id == "chain_lightning" and health > 0 and bonus_damage == 0:
		apply_shock(2.5)
	if bonus_damage > 0:
		_refresh_elemental_feedback()
	return bonus_damage

## Sword hits meet the elements: a chilled foe shatters, a shocked one
## conducts the blow to its neighbours. Returns bonus damage dealt.
func react_to_melee(damage: int) -> int:
	if health <= 0:
		return 0
	if slow_time_left > 0.0 and slow_factor < 0.95:
		slow_time_left = 0.0
		slow_factor = 1.0
		_announce_reaction("shatter", "РАСКОЛ!")
		var shatter := maxi(1, roundi(damage * 0.6))
		take_elemental_damage(shatter, "ice")
		return shatter
	if shock_time_left > 0.0:
		shock_time_left = 0.0
		_announce_reaction("conduct", "ПРОВОДНИК!")
		var arc := maxi(1, roundi(damage * 0.5))
		var struck := 0
		for other in _enemies_near(90.0):
			if struck >= 2:
				break
			if other.has_method("take_elemental_damage"):
				other.take_elemental_damage(arc, "lightning")
				struck += 1
		Vfx.burst(get_parent(), global_position, [Color(1, 1, 1), Color(0.85, 0.75, 1.0), Color(0.5, 0.4, 1.0, 0)], 12, 80.0, 0.3)
		return arc * struck
	return 0

func apply_slow(multiplier: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(multiplier, 0.1, 1.0))
	slow_time_left = maxf(slow_time_left, duration * get_status_duration_multiplier("ice"))
	_refresh_elemental_feedback()

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	if invulnerable:
		# A boss shield (BossMechanics): the blow glances off.
		if combat_feedback != null:
			combat_feedback.show_damage(0)
		return
	health -= amount
	if combat_feedback != null:
		combat_feedback.set_health(health, max_health)
		combat_feedback.show_damage(amount)
	Vfx.flash(visual)
	GameAudio.play("hit", -6.0, 0.12)
	var arena := get_parent()
	if health > 0 and amount * 4 >= max_health and arena != null and arena.has_method("hit_stop"):
		arena.hit_stop(0.045)
	if health <= 0:
		GameAudio.play("enemy_die", -4.0, 0.1)
		if arena != null and arena.has_method("hit_stop"):
			arena.hit_stop(0.06)
		Vfx.defeat(get_parent(), global_position)
		Vfx.dissolve(get_parent(), visual)
		defeated.emit(xp_reward)
		queue_free()
