extends "res://scripts/grove_guardian.gd"
class_name CrabKing

## Side boss of the Salt Coast: spits foam orbs; enraged, calls crabs.

const CRAB_SCRIPT := preload("res://scripts/coast_crab.gd")

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/crab_king_8dir.png"
	sprite_scale = 1.25
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 6.0)
	visual.offset = Vector2(0.0, -16.0)
	elemental_multipliers = {"fire": 0.8, "ice": 1.0, "lightning": 1.35}
	max_health = 230
	health = max_health
	xp_reward = 180
	combat_feedback.bar_y = -46.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged and health > 0:
		base_visual_tint = Color(1.1, 1.0, 0.9)
		visual.modulate = base_visual_tint
		var parent := get_parent()
		if parent == null:
			return
		for offset in [Vector2(-48, 14), Vector2(48, 14)]:
			var crab := CRAB_SCRIPT.new() as SlimeEnemy
			crab.position = global_position + offset
			parent.add_child(crab)
			# Called to the fight: they come running, not buried.
			crab.call("emerge")
			if parent.has_method("_on_enemy_defeated"):
				crab.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, crab.global_position))
			Vfx.sparkle(parent, crab.global_position)
