extends "res://scripts/vail_boss.gd"
class_name CryptLord

## Boss of the ruins depths: Vail's moves (blinks, orb rings) in a dead
## Keeper's body; enraged, he raises skeletons instead of shades.

const SKELETON_SCRIPT := preload("res://scripts/skeleton.gd")

func _ready() -> void:
	super._ready()
	visual.configure_chibi("crypt_lord", 8.0, 1.6)
	elemental_multipliers = {"fire": 1.25, "ice": 0.9, "lightning": 1.0}
	max_health = 240
	health = max_health
	xp_reward = 200
	combat_feedback.set_health(health, max_health)

func _summon_shades() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for offset in [Vector2(-60, 10), Vector2(60, 10)]:
		var bones := SKELETON_SCRIPT.new() as SlimeEnemy
		bones.position = global_position + offset
		parent.add_child(bones)
		if parent.has_method("_on_enemy_defeated"):
			bones.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, bones.global_position))
		Vfx.sparkle(parent, bones.global_position)
