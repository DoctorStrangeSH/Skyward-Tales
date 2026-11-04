extends "res://scripts/enemy.gd"
class_name Skeleton

## Ruins skeleton: a plain melee chaser in the pack's chibi style.

func _ready() -> void:
	sprite_fps = 8.0
	super._ready()
	visual.configure_chibi("skeleton", 8.0, sprite_scale)
	max_health = 40
	health = max_health
	move_speed = 40.0
	xp_reward = 24
	attack_damage = 9
	elemental_multipliers = {"fire": 1.15, "ice": 0.8, "lightning": 1.3}
	combat_feedback.set_health(health, max_health)
