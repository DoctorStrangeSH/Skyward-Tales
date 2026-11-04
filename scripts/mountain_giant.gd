extends "res://scripts/grove_guardian.gd"
class_name MountainGiant

## Side boss of the Stone Pass: hurls rock orbs; enraged, wakes two golems.

const GOLEM_SCRIPT := preload("res://scripts/stone_golem.gd")

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/mountain_giant_8dir.png"
	sprite_scale = 1.35
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 4.0)
	visual.offset = Vector2(0.0, -18.0)
	elemental_multipliers = {"fire": 0.7, "ice": 1.35, "lightning": 1.0}
	max_health = 360
	health = max_health
	xp_reward = 260
	combat_feedback.bar_y = -52.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged and health > 0:
		var parent := get_parent()
		if parent == null:
			return
		if parent.has_method("shake"):
			parent.shake(5.0, 0.5)
		for offset in [Vector2(-56, 16), Vector2(56, 16)]:
			var golem := GOLEM_SCRIPT.new() as SlimeEnemy
			golem.position = global_position + offset
			parent.add_child(golem)
			if parent.has_method("_on_enemy_defeated"):
				golem.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, golem.global_position))
			Vfx.sparkle(parent, golem.global_position)
