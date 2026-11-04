extends "res://scripts/stone_golem.gd"
class_name MagmaGolem

## Ashen Waste golem of cooled lava: tougher and hotter than the Pass ones.

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/magma_golem_8dir.png"
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 4.0)
	max_health = 130
	health = max_health
	xp_reward = 70
	attack_damage = 18
	elemental_multipliers = {"fire": 0.3, "ice": 1.5, "lightning": 1.0}
	combat_feedback.set_health(health, max_health)
