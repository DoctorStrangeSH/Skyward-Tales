extends RefCounted
class_name EliteModifiers

## Elite enemy modifiers from data/elites.json. Elites are bigger, glow,
## show their title, give double experience and always drop equipment.

const PATH := "res://data/elites.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

static func has(elite_id: String) -> bool:
	return data().get("modifiers", {}).has(elite_id)

static func can_be_elite(kind: String) -> bool:
	return kind in data().get("kinds", [])

static func roll(rng: RandomNumberGenerator) -> String:
	if rng.randf() >= float(data().get("random_chance", 0.0)):
		return ""
	var ids: Array = data().get("modifiers", {}).keys()
	return str(ids[rng.randi_range(0, ids.size() - 1)]) if not ids.is_empty() else ""

## Applies an elite modifier to a freshly created (not yet ready) enemy.
static func apply(enemy: SlimeEnemy, elite_id: String) -> void:
	if not has(elite_id):
		return
	enemy.elite_id = elite_id
	enemy.sprite_scale *= 1.25

## Second half, after _ready(): stats, colours, aura and title.
static func finish(enemy: SlimeEnemy) -> void:
	if enemy.elite_id.is_empty() or not has(enemy.elite_id):
		return
	var mod: Dictionary = data()["modifiers"][enemy.elite_id]
	enemy.max_health = roundi(enemy.max_health * float(mod.get("health_mult", 1.0)))
	enemy.health = enemy.max_health
	enemy.attack_damage = roundi(enemy.attack_damage * float(mod.get("damage_mult", 1.0)))
	enemy.move_speed *= float(mod.get("speed_mult", 1.0))
	enemy.attack_cooldown_duration *= float(mod.get("cooldown_mult", 1.0))
	enemy.knockback_resist = maxf(enemy.knockback_resist, float(mod.get("knockback_resist", 0.0)))
	enemy.xp_reward *= 2
	var rgb: Array = mod.get("color", [1, 0.7, 0.3])
	var color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	enemy.base_visual_tint = Color.WHITE.lerp(color, 0.35)
	enemy.visual.modulate = enemy.base_visual_tint
	enemy.combat_feedback.elite = true
	enemy.combat_feedback.elite_name = str(mod.get("name", ""))
	enemy.combat_feedback.elite_color = color
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
	var aura := CPUParticles2D.new()
	aura.name = "EliteAura"
	aura.amount = 10
	aura.lifetime = 0.9
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 10.0
	aura.position = Vector2(0, -12)
	aura.direction = Vector2.UP
	aura.spread = 30.0
	aura.gravity = Vector2(0, -20)
	aura.initial_velocity_min = 4.0
	aura.initial_velocity_max = 10.0
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(color, 0.9), Color(color, 0.0)])
	aura.color_ramp = gradient
	enemy.add_child(aura)
