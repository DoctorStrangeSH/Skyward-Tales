extends "res://scripts/pattern_voice.gd"
class_name PatternShade

## Post-game superboss in the Heart of the Sky: the darkness the Voice held
## back, gathered from the closed rifts. A violet copy of the Voice with
## denser volleys; enraged, it calls shades of the rift twice.

var _second_call: bool = false

func _ready() -> void:
	super._ready()
	elemental_multipliers = {"fire": 1.2, "ice": 1.0, "lightning": 0.9}
	max_health = 2400
	health = max_health
	xp_reward = 2400
	attack_damage = 34
	base_visual_tint = Color(0.82, 0.64, 1.0)
	visual.modulate = base_visual_tint
	combat_feedback.set_health(health, max_health)
	# A violet glow so the Shadow stands out even at night.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = ramp
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.texture = glow_texture
	light.texture_scale = 2.4
	light.color = Color(0.75, 0.5, 1.0)
	light.energy = 1.3
	light.position = Vector2(0, -30)
	add_child(light)

func _shoot_at(target_position: Vector2) -> void:
	var aim: Vector2 = (target_position - global_position).normalized()
	if aim.length_squared() < 0.001:
		aim = Vector2.DOWN
	var count := 16 if enraged else 7
	var spread := TAU if enraged else 1.2
	var turn := randf() * 0.3
	for i in count:
		var t := (float(i) / count) if enraged else (float(i) / (count - 1) - 0.5)
		var orb := ORB_SCRIPT.new() as EnemyMagicOrb
		orb.outer_color = Color(0.7, 0.4, 1.0)
		orb.core_color = Color(1.0, 0.9, 1.0)
		orb.setup(aim.rotated(t * spread + (turn if enraged else 0.0)), 18 if enraged else 16)
		orb.global_position = global_position
		get_parent().add_child(orb)

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if not _second_call and health > 0 and health < max_health * 0.3:
		_second_call = true
		_summon_bats()

## Instead of crystal bats, shades of the rift.
func _summon_bats() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent.has_method("shake"):
		parent.shake(5.0, 0.4)
	for offset in [Vector2(-50, -10), Vector2(50, -10), Vector2(0, 46)]:
		if parent.has_method("spawn_enemy"):
			var shade: SlimeEnemy = parent.spawn_enemy("shade", global_position + offset)
			if shade != null:
				Vfx.sparkle(parent, shade.global_position)
