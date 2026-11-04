extends "res://scripts/forest_wolf.gd"
class_name EmberHound

## Ashen Waste hound: a charcoal wolf with ember eyes. Faster lunge than its
## forest cousin; fire barely hurts it, frost cracks it.

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/ember_hound_8dir.png"
	visual.configure(sprite_sheet, 4, 8, 1.0, 9.0)
	max_health = 58
	health = max_health
	move_speed = 62.0
	xp_reward = 46
	attack_damage = 14
	attack_lunge_speed = 300.0
	elemental_multipliers = {"fire": 0.4, "ice": 1.45, "lightning": 1.0}
	combat_feedback.set_health(health, max_health)
