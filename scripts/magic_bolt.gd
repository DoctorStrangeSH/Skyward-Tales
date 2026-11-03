extends Area2D
class_name MagicBolt

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const FIREBALL_SHEET := "res://assets/sprites/magic/fireball_8dir.png"

@export var speed: float = 255.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 18
var lifetime: float = 2.0
var spell_id: String = "fireball"
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var burn_damage: int = 0
var burn_duration: float = 0.0
var chain_targets: int = 0
var chain_radius: float = 0.0
var chain_damage_factor: float = 0.65
var visual: DirectionalSprite
## Skill-tree ultimates: fire explosion radius, extra frost pierces.
var explode_radius: float = 0.0
var pierce_left: int = 0
var freeze_on_hit: bool = false
var _already_hit: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(_sheet_for(spell_id), 4, 8, 1.0, 16.0)
	visual.set_direction_vector(direction)
	visual.set_moving(true)
	# Drawn at hand height; the hitbox stays at ground level where enemies are.
	visual.offset = Vector2(0, -8)
	add_child(visual)

func setup(flight_direction: Vector2, spell_damage: int) -> void:
	direction = flight_direction.normalized()
	damage = spell_damage
	if visual != null:
		visual.set_direction_vector(direction)

func configure_effect(new_spell_id: String, new_slow_multiplier: float, new_slow_duration: float) -> void:
	spell_id = new_spell_id
	slow_multiplier = clampf(new_slow_multiplier, 0.1, 1.0)
	slow_duration = maxf(new_slow_duration, 0.0)
	if visual != null:
		visual.configure(_sheet_for(spell_id), 4, 8, 1.0, 16.0)
		visual.set_direction_vector(direction)
		visual.set_moving(true)

static func _sheet_for(id: String) -> String:
	match id:
		"frostbolt":
			return "res://assets/sprites/magic/frostbolt_8dir.png"
		"chain_lightning":
			return "res://assets/sprites/magic/chain_lightning_8dir.png"
	return FIREBALL_SHEET

func configure_burning(damage_per_tick: int, duration: float) -> void:
	burn_damage = maxi(0, damage_per_tick)
	burn_duration = maxf(0.0, duration)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body in _already_hit:
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		_already_hit.append(body)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction, 90.0)
		body.take_elemental_damage(damage, _element_for_spell()) if body.has_method("take_elemental_damage") else body.take_damage(damage)
		if not body.is_queued_for_deletion() and body.has_method("react_to_spell"):
			body.react_to_spell(spell_id)
		if spell_id == "fireball" and burn_duration > 0.0 and body.has_method("apply_burning") and not body.is_queued_for_deletion():
			body.apply_burning(burn_damage, burn_duration)
		if spell_id == "chain_lightning":
			_apply_chain_lightning(body)
		if spell_id == "frostbolt" and body.has_method("apply_slow") and slow_duration > 0.0:
			body.apply_slow(0.1 if freeze_on_hit else slow_multiplier, maxf(slow_duration, 1.0) if freeze_on_hit else slow_duration)
		if explode_radius > 0.0:
			_explode(body)
		Vfx.spell_impact(get_parent(), global_position, spell_id)
		if pierce_left > 0:
			pierce_left -= 1
			return
		queue_free()
	elif body is StaticBody2D:
		Vfx.spell_impact(get_parent(), global_position, spell_id)
		queue_free()

## "Пламя феникса": half damage and burning to every enemy around the target.
func _explode(center_body: Node2D) -> void:
	var center := center_body.global_position
	Vfx.burst(get_parent(), center, Vfx.SPELL_COLORS["fireball"], 28, 110.0, 0.5)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or enemy == center_body or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(center) > explode_radius:
			continue
		var splash := maxi(1, damage / 2)
		enemy.take_elemental_damage(splash, "fire") if enemy.has_method("take_elemental_damage") else enemy.take_damage(splash)
		if not enemy.is_queued_for_deletion() and enemy.has_method("apply_burning") and burn_duration > 0.0:
			enemy.apply_burning(burn_damage, burn_duration)

func _element_for_spell() -> String:
	match spell_id:
		"fireball": return "fire"
		"frostbolt": return "ice"
		"chain_lightning": return "lightning"
	return "arcane"

func _apply_chain_lightning(first_target: Node2D) -> void:
	# Each hop originates at the last struck enemy; never hit the same enemy twice.
	var hit: Array[Node2D] = [first_target]
	var origin: Vector2 = first_target.global_position
	var next_damage: int = damage
	for hop in range(chain_targets):
		var closest: Node2D = null
		var closest_squared: float = chain_radius * chain_radius
		for candidate in get_tree().get_nodes_in_group("enemies"):
			var enemy := candidate as Node2D
			if enemy == null or enemy in hit or enemy.is_queued_for_deletion():
				continue
			if not enemy.has_method("take_damage"):
				continue
			var distance_squared: float = origin.distance_squared_to(enemy.global_position)
			if distance_squared < closest_squared:
				closest_squared = distance_squared
				closest = enemy
		if closest == null:
			break
		next_damage = maxi(1, int(round(float(next_damage) * chain_damage_factor)))
		var destination: Vector2 = closest.global_position
		closest.take_elemental_damage(next_damage, "lightning") if closest.has_method("take_elemental_damage") else closest.take_damage(next_damage)
		if not closest.is_queued_for_deletion() and closest.has_method("react_to_spell"):
			closest.react_to_spell("chain_lightning")
		# Visual tether is temporary; it doesn't affect damage or target selection.
		_spawn_lightning_flash(origin, destination)
		hit.append(closest)
		origin = destination

func _spawn_lightning_flash(from_point: Vector2, to_point: Vector2) -> void:
	var flash := Line2D.new()
	flash.width = 2.0
	flash.default_color = Color(0.77, 0.87, 1.0, 0.9)
	flash.add_point(from_point)
	flash.add_point((from_point + to_point) * 0.5 + Vector2(0, -4))
	flash.add_point(to_point)
	flash.top_level = true
	get_parent().add_child(flash)
	var timer := get_tree().create_timer(0.14, false)
	timer.timeout.connect(flash.queue_free)
