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
	# Temporary tint distinguishes the wolf until its dedicated atlas is ready.
	base_visual_tint = Color(0.78, 0.88, 0.72)
	super._ready()
