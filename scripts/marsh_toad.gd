extends "res://scripts/forest_wolf.gd"
class_name MarshToad

## Misty Marsh toad: sits still, then leaps at the hero (the wolf's lunge).

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/marsh_toad_8dir.png"
	visual.configure(sprite_sheet, 4, 8, 1.0, 6.0)
	visual.offset = Vector2(0.0, -11.0)
	max_health = 30
	health = max_health
	move_speed = 40.0
	xp_reward = 22
	attack_damage = 8
	attack_lunge_speed = 260.0
	elemental_multipliers = {"fire": 1.3, "ice": 0.8, "lightning": 1.0}
	combat_feedback.set_health(health, max_health)
