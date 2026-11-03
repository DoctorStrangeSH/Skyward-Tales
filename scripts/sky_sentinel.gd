extends "res://scripts/forest_shaman.gd"
class_name SkySentinel

## Stone-and-brass construct of the Keepers guarding the sky island.
## Keeps its distance and fires bolts; slow, sturdy, weak to lightning.

func _ready() -> void:
	sprite_sheet = "res://assets/sprites/enemies/sky_sentinel_8dir.png"
	sprite_fps = 5.0
	super._ready()
	max_health = 60
	health = max_health
	xp_reward = 34
	move_speed = 30.0
	attack_cooldown_duration = 2.0
	elemental_multipliers = {"lightning": 1.35, "ice": 0.8, "fire": 0.9}
	knockback_resist = 0.5
	combat_feedback.set_health(health, max_health)
