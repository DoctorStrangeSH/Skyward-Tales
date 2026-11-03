extends "res://scripts/forest_shaman.gd"
class_name GroveGuardian

var enraged: bool = false

func _ready() -> void:
	sprite_sheet = "res://assets/sprites/enemies/grove_guardian_8dir.png"
	sprite_offset = Vector2(0.0, -19.0)
	sprite_fps = 4.0
	super._ready()
	elemental_multipliers = {"fire": 0.65, "ice": 1.25, "lightning": 1.0}
	max_health = 160
	health = max_health
	xp_reward = 100
	move_speed = 25.0
	attack_cooldown_duration = 2.2
	detection_radius = 340.0
	give_up_radius = 440.0
	shooting_distance = 300.0
	preferred_distance = 180.0
	retreat_distance = 120.0
	visual.modulate = base_visual_tint
	combat_feedback.elite = true
	combat_feedback.bar_y = -46.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	if not enraged and health - amount <= max_health / 2 and health - amount > 0:
		enraged = true
		combat_feedback.set_warning(true)
		move_speed = 44.0
		attack_cooldown_duration = 1.2
		base_visual_tint = Color(1.0, 0.62, 0.55)
		visual.modulate = base_visual_tint
	super.take_damage(amount)

func _shoot_at(target_position: Vector2) -> void:
	var aim: Vector2 = (target_position - global_position).normalized()
	if aim.length_squared() < 0.001:
		aim = Vector2.DOWN
	for angle in ([-0.22, 0.0, 0.22] if enraged else [0.0]):
		var orb := ORB_SCRIPT.new() as EnemyMagicOrb
		orb.setup(aim.rotated(float(angle)), 12 if enraged else 10)
		orb.global_position = global_position
		get_parent().add_child(orb)
