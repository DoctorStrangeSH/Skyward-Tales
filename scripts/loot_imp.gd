extends "res://scripts/enemy.gd"
class_name LootImp

## World event: a golden thief imp with a sack of treasure. It never fights,
## only flees from the hero, and vanishes after a while. Caught — it bursts
## into coins and a piece of fine gear.

signal escaped

const LIFETIME := 26.0

var time_left: float = LIFETIME

func _ready() -> void:
	sprite_sheet = "res://assets/sprites/enemies/loot_imp_8dir.png"
	sprite_fps = 10.0
	super._ready()
	max_health = 60
	health = max_health
	move_speed = 66.0
	xp_reward = 40
	attack_damage = 0
	knockback_resist = 0.3
	combat_feedback.set_health(health, max_health)

func _physics_process(delta: float) -> void:
	_apply_knockback(delta)
	_update_burning(delta)
	if is_queued_for_deletion() or health <= 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		Vfx.sparkle(get_parent(), global_position)
		escaped.emit()
		queue_free()
		return
	slow_time_left = maxf(0.0, slow_time_left - delta)
	if slow_time_left <= 0.0:
		slow_factor = 1.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var away: Vector2 = global_position - player.global_position
	var desired := Vector2.ZERO
	if away.length() < 150.0:
		desired = away.normalized().rotated(sin(time_left * 3.0) * 0.6)
	if desired.length_squared() > 0.001:
		var steered: Vector2 = _avoid_world_obstacles(desired, delta)
		velocity = steered * move_speed * slow_factor
		visual.set_direction_vector(steered)
		visual.set_moving(true)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		visual.set_moving(false)
	# Glitter trail.
	if Engine.get_physics_frames() % 12 == 0:
		Vfx.sparkle(get_parent(), global_position + Vector2(0, -6))
