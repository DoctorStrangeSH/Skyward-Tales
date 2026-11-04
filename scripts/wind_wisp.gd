extends "res://scripts/forest_wolf.gd"
class_name WindWisp

## Wind spirit of the Wind Spires: circles close, then darts forward like a
## wolf's lunge. Light and quick; burns well, shrugs off frost.

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/wind_wisp_8dir.png"
	visual.configure(sprite_sheet, 4, 8, 1.0, 10.0)
	visual.offset = Vector2(0.0, -10.0)
	max_health = 36
	health = max_health
	move_speed = 64.0
	xp_reward = 28
	attack_damage = 10
	attack_lunge_speed = 300.0
	elemental_multipliers = {"fire": 1.3, "ice": 0.8, "lightning": 1.0}
	combat_feedback.set_health(health, max_health)
