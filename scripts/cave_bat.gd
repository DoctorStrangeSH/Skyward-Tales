extends "res://scripts/enemy.gd"
class_name CaveBat

## Fast, fragile crystal bat that zig-zags towards the hero and bites.

var _flutter_clock: float = 0.0

func _ready() -> void:
	max_health = 22
	move_speed = 72.0
	xp_reward = 18
	detection_radius = 200.0
	give_up_radius = 300.0
	attack_damage = 7
	attack_range = 16.0
	attack_cooldown_duration = 1.1
	elemental_multipliers = {"lightning": 1.4, "ice": 0.75}
	sprite_sheet = "res://assets/sprites/enemies/cave_bat_8dir.png"
	sprite_offset = Vector2(0.0, -12.0)
	sprite_fps = 12.0
	_flutter_clock = randf() * TAU
	super._ready()
	combat_feedback.bar_y = -33.0

func _shape_chase(direction: Vector2, delta: float) -> Vector2:
	_flutter_clock += delta * 7.0
	var side := Vector2(-direction.y, direction.x) * sin(_flutter_clock) * 0.85
	return (direction + side).normalized()
