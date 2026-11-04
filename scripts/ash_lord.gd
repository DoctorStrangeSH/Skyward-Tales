extends "res://scripts/grove_guardian.gd"
class_name AshLord

## Boss of the Ashen Waste, in the crater: a giant of obsidian and magma.
## Throws fire orbs (a fan when enraged) and, enraged, calls two ember hounds.

const HOUND_SCRIPT := preload("res://scripts/ember_hound.gd")

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/ash_lord_8dir.png"
	sprite_scale = 1.4
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 4.0)
	visual.offset = Vector2(0.0, -18.0)
	elemental_multipliers = {"fire": 0.25, "ice": 1.4, "lightning": 1.0}
	max_health = 520
	health = max_health
	xp_reward = 420
	attack_damage = 20
	combat_feedback.bar_y = -54.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged and health > 0:
		var parent := get_parent()
		if parent == null:
			return
		if parent.has_method("shake"):
			parent.shake(6.0, 0.6)
		for offset in [Vector2(-60, 18), Vector2(60, 18)]:
			var hound := HOUND_SCRIPT.new() as SlimeEnemy
			hound.position = global_position + offset
			parent.add_child(hound)
			if parent.has_method("_on_enemy_defeated"):
				hound.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, hound.global_position, "ember_hound"))
			Vfx.burst(parent, hound.global_position, [Color(1, 0.9, 0.5), Color(1, 0.5, 0.2), Color(0.4, 0.1, 0.05, 0)], 14, 70.0, 0.5)

func _shoot_at(target_position: Vector2) -> void:
	var aim: Vector2 = (target_position - global_position).normalized()
	if aim.length_squared() < 0.001:
		aim = Vector2.DOWN
	for angle in ([-0.3, -0.1, 0.1, 0.3] if enraged else [-0.12, 0.12]):
		var orb := (ORB_SCRIPT.new() as EnemyMagicOrb).make_fire()
		orb.setup(aim.rotated(float(angle)), 15 if enraged else 13)
		orb.global_position = global_position
		get_parent().add_child(orb)
