extends "res://scripts/enemy.gd"
class_name StoneGolem

## Stone Pass golem: slow, very tough melee bruiser that shrugs off knockback.

func _ready() -> void:
	sprite_sheet = "res://assets/sprites/enemies/stone_golem_8dir.png"
	sprite_offset = Vector2(0.0, -12.0)
	sprite_fps = 4.0
	super._ready()
	max_health = 90
	health = max_health
	move_speed = 26.0
	xp_reward = 44
	attack_damage = 14
	knockback_resist = 0.8
	elemental_multipliers = {"fire": 0.7, "ice": 1.3, "lightning": 1.0}
	combat_feedback.set_health(health, max_health)
