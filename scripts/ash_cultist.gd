extends "res://scripts/forest_shaman.gd"
class_name AshCultist

## Crimson-robed cultist of the Ash Lord: keeps its distance and hurls
## fireballs.

func _ready() -> void:
	sprite_fps = 6.0
	super._ready()
	visual.configure_chibi("ash_cultist", 6.0, sprite_scale)
	max_health = 50
	health = max_health
	xp_reward = 52
	elemental_multipliers = {"fire": 0.5, "ice": 1.3, "lightning": 1.15}
	combat_feedback.set_health(health, max_health)

func _shoot_at(target_position: Vector2) -> void:
	var orb := (ORB_SCRIPT.new() as EnemyMagicOrb).make_fire()
	orb.setup(target_position - global_position, 13)
	orb.speed = 170.0
	orb.position = global_position
	get_parent().add_child(orb)
