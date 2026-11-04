extends "res://scripts/grove_guardian.gd"
class_name BogKing

## Side boss of the Misty Marsh: spits poison orbs; enraged, calls toads.

const TOAD_SCRIPT := preload("res://scripts/marsh_toad.gd")

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/bog_king_8dir.png"
	sprite_scale = 1.25
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 5.0)
	visual.offset = Vector2(0.0, -18.0)
	elemental_multipliers = {"fire": 1.35, "ice": 0.85, "lightning": 1.0}
	max_health = 260
	health = max_health
	xp_reward = 200
	combat_feedback.bar_y = -48.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged and health > 0:
		base_visual_tint = Color(1.05, 1.15, 0.8)
		visual.modulate = base_visual_tint
		_summon_toads()

func _summon_toads() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent.has_method("shake"):
		parent.shake(3.5, 0.35)
	for offset in [Vector2(-50, 16), Vector2(50, 16)]:
		var toad := TOAD_SCRIPT.new() as SlimeEnemy
		toad.position = global_position + offset
		parent.add_child(toad)
		if parent.has_method("_on_enemy_defeated"):
			toad.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, toad.global_position))
		Vfx.sparkle(parent, toad.global_position)
