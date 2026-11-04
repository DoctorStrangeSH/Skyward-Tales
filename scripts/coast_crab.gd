extends "res://scripts/forest_wolf.gd"
class_name CoastCrab

## Salt Coast crab: scuttles close, then snaps forward (the wolf's lunge).

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/coast_crab_8dir.png"
	visual.configure(sprite_sheet, 4, 8, 1.0, 8.0)
	visual.offset = Vector2(0.0, -10.0)
	max_health = 34
	health = max_health
	move_speed = 44.0
	xp_reward = 20
	attack_damage = 8
	attack_lunge_speed = 240.0
	elemental_multipliers = {"fire": 0.8, "ice": 1.0, "lightning": 1.3}
	combat_feedback.set_health(health, max_health)
