extends "res://scripts/enemy.gd"
class_name ForestWolf

func _ready() -> void:
	max_health = 48
	move_speed = 56.0
	xp_reward = 24
	detection_radius = 220.0
	give_up_radius = 310.0
	super._ready()
	# Placeholder tint until a dedicated eight-direction wolf atlas is authored.
	if visual != null:
		visual.modulate = Color(0.78, 0.88, 0.72)
