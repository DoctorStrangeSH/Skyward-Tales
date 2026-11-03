extends "res://scripts/grove_guardian.gd"
class_name EchoWarden

## Act I finale boss: a living crystal born from the broken altar.
## Shoots crystal orbs; when enraged it calls two crystal bats.

const BAT_SCRIPT := preload("res://scripts/cave_bat.gd")

var summoned: bool = false

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/echo_warden_8dir.png"
	visual.configure(sprite_sheet, 4, 8, 1.0, 5.0)
	visual.offset = Vector2(0.0, -20.0)
	elemental_multipliers = {"fire": 1.2, "ice": 0.8, "lightning": 0.7}
	max_health = 220
	health = max_health
	xp_reward = 160
	move_speed = 30.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged and not summoned and health > 0:
		summoned = true
		_summon_bats()

func _summon_bats() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for offset in [Vector2(-40, -10), Vector2(40, -10)]:
		var bat := BAT_SCRIPT.new() as SlimeEnemy
		bat.position = global_position + offset
		parent.add_child(bat)
		if parent.has_method("_on_enemy_defeated"):
			bat.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, bat.global_position))
		Vfx.sparkle(parent, bat.global_position)
