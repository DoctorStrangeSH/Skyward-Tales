extends "res://scripts/stone_golem.gd"
class_name OreGolem

## "Рудный вожак": the golem that leads the pack in the overrun Stone Pass
## mine. Huge, copper-veined, hits hard; beating it frees the mine.

func _ready() -> void:
	super._ready()
	max_health = 520
	health = max_health
	attack_damage = 24
	xp_reward = 320
	move_speed = 30.0
	knockback_resist = 0.95
	visual.scale *= 1.45
	base_visual_tint = Color(1.0, 0.72, 0.5)
	visual.modulate = base_visual_tint
	combat_feedback.elite = true
	combat_feedback.elite_name = "Рудный вожак"
	combat_feedback.elite_color = Color(1.0, 0.65, 0.35)
	combat_feedback.bar_y *= 1.45
	combat_feedback.set_health(health, max_health)
