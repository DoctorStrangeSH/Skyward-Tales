extends "res://scripts/echo_warden.gd"
class_name PatternVoice

## Final boss of Act III in the Heart of the Sky: what is left of the Pattern
## itself — a towering crystal of light. Volleys of light orbs (a full ring
## when enraged) and summoned crystal bats.

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/pattern_voice_8dir.png"
	sprite_scale = 1.7
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 5.0)
	visual.offset = Vector2(0.0, -28.0)
	elemental_multipliers = {"fire": 1.0, "ice": 1.0, "lightning": 0.8}
	max_health = 1100
	health = max_health
	xp_reward = 900
	attack_damage = 26
	knockback_resist = 0.9
	combat_feedback.bar_y = -64.0
	combat_feedback.set_health(health, max_health)

func _shoot_at(target_position: Vector2) -> void:
	var aim: Vector2 = (target_position - global_position).normalized()
	if aim.length_squared() < 0.001:
		aim = Vector2.DOWN
	var count := 12 if enraged else 5
	var spread := TAU if enraged else 0.9
	for i in count:
		var t := (float(i) / count) if enraged else (float(i) / (count - 1) - 0.5)
		var orb := ORB_SCRIPT.new() as EnemyMagicOrb
		orb.outer_color = Color(1.0, 0.92, 0.55)
		orb.core_color = Color(1, 1, 1)
		orb.setup(aim.rotated(t * spread), 16 if enraged else 14)
		orb.global_position = global_position
		get_parent().add_child(orb)
