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

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(FIREBALL_SHEET, 4, 8, 1.8, 16.0)
	visual.set_direction_vector(direction)
	visual.set_moving(true)
	if spell_id == "frostbolt":
		visual.modulate = Color(0.38, 0.82, 1.0)
	elif spell_id == "chain_lightning":
		visual.modulate = Color(0.78, 0.66, 1.0)
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
		visual.modulate = Color(0.38, 0.82, 1.0) if spell_id == "frostbolt" else (Color(0.78, 0.66, 1.0) if spell_id == "chain_lightning" else Color.WHITE)

func configure_burning(damage_per_tick: int, duration: float) -> void:
	burn_damage = maxi(0, damage_per_tick)
	burn_duration = maxf(0.0, duration)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if spell_id == "fireball" and burn_duration > 0.0 and body.has_method("apply_burning") and not body.is_queued_for_deletion():
			body.apply_burning(burn_damage, burn_duration)
		if spell_id == "chain_lightning":
			_apply_chain_lightning(body)
		if spell_id == "frostbolt" and body.has_method("apply_slow") and slow_duration > 0.0:
			body.apply_slow(slow_multiplier, slow_duration)
		queue_free()
	elif body is StaticBody2D:
		queue_free()

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
		closest.take_damage(next_damage)
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
