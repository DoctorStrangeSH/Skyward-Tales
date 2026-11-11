extends "res://scripts/enemy.gd"
class_name ForestWolf

func _ready() -> void:
	max_health = 48
	move_speed = 56.0
	xp_reward = 24
	detection_radius = 220.0
	give_up_radius = 310.0
	attack_damage = 12
	attack_range = 74.0
	attack_cooldown_duration = 1.8
	attack_windup_duration = 0.42
	attack_lunge_duration = 0.22
	attack_lunge_speed = 270.0
	attack_hit_radius = 20.0
	elemental_multipliers = {"fire": 1.25, "ice": 0.8}
	sprite_sheet = "res://assets/sprites/enemies/forest_wolf_8dir.png"
	sprite_fps = 9.0
	super._ready()

## Pack tactics: with a packmate nearby, wolves do not run at the hero in a
## line — each takes its own side and they close in from two directions.
const PINCER_ANGLE := 0.75
const PACK_RANGE := 220.0

func pack_size() -> int:
	var count := 1
	for node in get_tree().get_nodes_in_group("enemies"):
		if node != self and node is ForestWolf and not node.is_queued_for_deletion() and (node as ForestWolf).visible \
				and (node as Node2D).global_position.distance_to(global_position) <= PACK_RANGE:
			count += 1
	return count

## -1 or +1: the side this wolf takes.
func pincer_side() -> int:
	return 1 if get_instance_id() % 2 == 0 else -1

func _shape_chase(direction: Vector2, delta: float) -> Vector2:
	if pack_size() < 2:
		return super._shape_chase(direction, delta)
	return direction.rotated(PINCER_ANGLE * pincer_side())
