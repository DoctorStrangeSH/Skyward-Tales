extends "res://scripts/ash_lord.gd"
class_name ForgeTitan

## Boss of the Forge Depths: the Titan of the Crucible, a huge magma golem.
## Fans of fire orbs; enraged, he calls ember hounds like his master did.

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/magma_golem_8dir.png"
	sprite_scale = 2.1
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 4.0)
	visual.offset = Vector2(0.0, -24.0)
	max_health = 780
	health = max_health
	xp_reward = 620
	attack_damage = 24
	knockback_resist = 0.95
	combat_feedback.bar_y = -62.0
	combat_feedback.set_health(health, max_health)
